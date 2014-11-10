/*
    Copyright (C) 2014 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/

namespace BirdFont {

public class BackgroundTools : ToolCollection  {
	Expander files;
	Expander parts;
	public Gee.ArrayList<Expander> expanders = new Gee.ArrayList<Expander> ();
	
	public BackgroundTools () {
		BackgroundSelectionTool select_background = new BackgroundSelectionTool ();
		Expander background_selection = new Expander (t_("Images"));
		Expander background_tools = new Expander ();

		Expander font_name = new Expander ();
		font_name.add_tool (new FontName ());
		font_name.draw_separator = false;

		files = new Expander (t_("Files"));
		files.set_persistent (true);
		files.set_unique (true);

		parts = new Expander (t_("Parts"));
		parts.set_persistent (true);
		parts.set_unique (true);
		
		background_tools.add_tool (select_background);
		
		LabelTool add_new_image = new LabelTool (t_("Add"));
		add_new_image.select_action.connect ((t) => {
			load_image ();
		});
		background_selection.add_tool (add_new_image);

		background_tools.add_tool (DrawingTools.move_background);
		background_tools.add_tool (DrawingTools.move_canvas);
		background_tools.add_tool (DrawingTools.background_scale);

		expanders.add (font_name);
		expanders.add (background_tools);
		expanders.add (DrawingTools.view_tools);
		expanders.add (DrawingTools.guideline_tools);
		expanders.add (background_selection);
		expanders.add (files);
		expanders.add (parts);
	}

	public void remove_images () {
		files.tool.clear ();
		parts.tool.clear ();
	}

	void set_default_canvas () {
		MainWindow.get_tab_bar ().select_tab_name ("Backgrounds");
	}

	public void add_part (BackgroundSelection selection) {
		BackgroundPartLabel label;
		label = new BackgroundPartLabel (selection, t_("No Glyph Selected"));
		label.select_action.connect ((t) => {
			BackgroundPartLabel bpl = (BackgroundPartLabel) t;
			GlyphSelection gs = new GlyphSelection ();

			gs.selected_glyph.connect ((gc) => {
				bpl.selection.assigned_glyph = gc;
				bpl.label = gc.get_name ();
				set_default_canvas ();
			});
			
			if (!bpl.deleted) {
				GlyphCanvas.set_display (gs);	
			}			
		});
		label.delete_action.connect ((t) => {
			// don't invalidate the toolbox iterator
			IdleSource idle = new IdleSource (); 
			idle.set_callback (() => {
				GlyphCollection g;
				BackgroundPartLabel bpl;
				
				bpl = (BackgroundPartLabel) t;
				bpl.deleted = true;
				
				if (bpl.selection.assigned_glyph != null){
					g = (!) bpl.selection.assigned_glyph;
					g.get_current ().set_background_image (null);
				}
			
				parts.tool.remove (bpl);
				bpl.selection.parent_image.selections.remove (bpl.selection);
				MainWindow.get_toolbox ().update_expanders ();
				set_default_canvas ();
				Toolbox.redraw_tool_box ();
				GlyphCanvas.redraw ();
				return false;
			});
			idle.attach (null);
		});
		label.has_delete_button = true;
		parts.add_tool (label, 0);
		MainWindow.get_toolbox ().update_expanders ();
		Toolbox.redraw_tool_box ();
	}

	public override Gee.ArrayList<Expander> get_expanders () {
		return expanders;
	}

	void load_image () {
		FileChooser fc = new FileChooser ();
		fc.file_selected.connect ((fn) => {
			if (fn != null) {
				add_image_file ((!) fn);
			}
		});
		
		MainWindow.file_chooser (t_("Open"), fc, FileChooser.LOAD);
	}
	
	void add_image_file (string file_path) {
		File f = File.new_for_path (file_path);
		string fn = (!) f.get_basename ();
		BackgroundImage image = new BackgroundImage (file_path);
		int i;
		
		i = fn.index_of (".");
		if (i > -1) {
			fn = fn.substring (0, i);
		}
		
		image.name = fn;
		
		add_image (image);
		
		GlyphCanvas.redraw ();
		MainWindow.get_toolbox ().update_expanders ();
		Toolbox.redraw_tool_box ();
	}
	
	public void add_image (BackgroundImage image) {
		LabelTool image_selection;
		double xc, yc;
		BackgroundTab bt;
		Font font;
		
		font = BirdFont.get_current_font ();

		image_selection = new BackgroundSelectionLabel (image, image.name);
		image_selection.select_action.connect ((t) => {
			BackgroundTab background_tab = BackgroundTab.get_instance ();
			BackgroundSelectionLabel bg = (BackgroundSelectionLabel) t;
			
			if (!bg.deleted) {
				background_tab.set_background_image (bg.img);
				background_tab.set_background_visible (true);
				ZoomTool.zoom_full_background_image ();
				GlyphCanvas.redraw ();
			}
			
			set_default_canvas ();
		});
		
		image_selection.delete_action.connect ((t) => {
			// don't invalidate the toolbox iterator
			IdleSource idle = new IdleSource (); 
			idle.set_callback (() => {
				GlyphCollection g;
				BackgroundSelectionLabel bsl;
				Font f = BirdFont.get_current_font ();
				
				bsl = (BackgroundSelectionLabel) t;
				bsl.deleted = true;
			
				files.tool.remove (bsl);
				f.background_images.remove (bsl.img);

				MainWindow.get_toolbox ().update_expanders ();
				set_default_canvas ();
				Toolbox.redraw_tool_box ();
				GlyphCanvas.redraw ();
				return false;
			});
			idle.attach (null);
		});
		
		image_selection.has_delete_button = true;
		
		files.add_tool (image_selection);

		bt = BackgroundTab.get_instance ();
		bt.set_background_image (image);
		bt.set_background_visible (true);
		ZoomTool.zoom_full_background_image ();
		
		foreach (Tool t in files.tool) {
			t.set_selected (false);
		}
		image_selection.set_selected (true);

		bt.set_background_image (image);
		bt.set_background_visible (true);

		xc = image.img_middle_x;
		yc = image.img_middle_y;

		image.set_img_scale (0.2, 0.2);
		
		image.img_middle_x = xc;
		image.img_middle_y = yc;
				
		image.center_in_glyph ();
		ZoomTool.zoom_full_background_image ();
		
		font.add_background_image (image);
	}
	
	class BackgroundSelectionLabel : LabelTool {
		public BackgroundImage img;
		public bool deleted;
		public BackgroundSelectionLabel (BackgroundImage img, string base_name) {
			base (base_name);
			this.img = img;
			deleted = false;
		}
	}

	class BackgroundPartLabel : LabelTool {
		public bool deleted;
		public BackgroundSelection selection;
		public BackgroundPartLabel (BackgroundSelection selection, string base_name) {
			base (base_name);
			this.selection = selection;
			deleted = false;
		}
	}
}

}
