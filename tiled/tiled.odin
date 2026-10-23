package tiled

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"

/*
    Based on the JSON Map Format for Tiled 1.2.
    https://doc.mapeditor.org/en/stable/reference/json-map-format/

    TODO:
        - This needs to be extensively tested. You can help by e.g.
          sending me your Tiled files (as JSON) in order to give me
          testing material.
        - Comment all fields with the description in the link above.
          Textually separate optional fields and describe them as such.
        - Add the omitempty tag where appropriate.
*/

// parse_tilemap takes a Tiled tilemap JSON file
// and converts it into an Odin data structure.
parse_tilemap :: proc(path: string, alloc: mem.Allocator) -> (Map, bool) {
	m: Map
	jdata, read_err := os.read_entire_file(path, alloc)
	if read_err != nil {
		fmt.println("ODIN_TILED: Failed to read file: ", path)
		return m, false
	}

	err := json.unmarshal(jdata, &m, allocator = alloc)
	if err != nil {
		fmt.print("ODIN_TILED: Failed to unmarshal JSON: ", err, "\n")
		ext := filepath.ext(path)
		if ext == ".tmx" || ext == ".tsx" || ext == ".xml" {
			fmt.println("ODIN_TILED: file appears to be XML; only JSON is supported")
		}
		return m, false
	}
	return m, true
}


// tries to parse tilemap and all external tilesets.
// should probably be the default
parse_tilemap_and_tilesets :: proc(path: string, alloc: mem.Allocator) -> Map {
	m, ok := parse_tilemap(path, alloc)

	if !ok {
		panic("parse_tilemap_and_tilesets::error")
	}

	if !ok {
		panic("parse_tilemap_and_tilesets::error")
	}

	dir := filepath.dir(path)
	for &ts in m.tilesets {
		if ts.source == "" do continue
		ts_path, _ := filepath.join({dir, ts.source}, alloc)
		external_ts := parse_tileset(ts_path, alloc)

		// check could be better
		if external_ts.type == "" {
			fmt.printfln("Couldn't parse tileset %v", ts.source)
		}

		external_ts.first_gid = ts.first_gid
		external_ts.source = ts.source
		ts = external_ts
	}
	return m
}

// parse_tileset takes a Tiled tileset JSON file
// and converts it into an Odin data structure.
parse_tileset :: proc(path: string, alloc: mem.Allocator) -> Tileset {
	ts: Tileset
	jdata, read_err := os.read_entire_file(path, alloc)
	if read_err != nil {
		fmt.print("Failed to read file: ", path, "\n")
		return ts
	}

	err := json.unmarshal(jdata, &ts, allocator = alloc)
	if err != nil {
		fmt.print("ODIN_TILED: Failed to unmarshal JSON from ", path, ": ", err, "\n")
		ext := filepath.ext(path)
		if ext == ".tmx" || ext == ".tsx" || ext == ".xml" {
			fmt.println("ODIN_TILED: File appears to be XML; only JSON is supported")
		}
		return ts
	}
	return ts
}


// parse_template :: proc(path: string, alloc: mem.Allocator = context.allocator) -> Obj

// Array of unsigned int (GIDs) or base64-encoded data
ArrayOrString :: union {
	[]i32,
	string,
}

PropertyData :: union {
	string, // String / file / color
	bool, // Bool
	i32, // Int
	f32, // Float
}

// Map.type (only one entry, "map") and Tileset.type (one entry: "tileset") could also be enum-ified if desired.

MapOrientation :: enum {
	Orthogonal,
	Isometric,
	Oblique,
	Staggered,
	Hexagonal,
	orthogonal = Orthogonal,
	isometric = Isometric,
	oblique = Oblique,
	staggered = Staggered,
	hexagonal = Hexagonal,
}

MapStaggerAxis :: enum {
	x,
	y,
}

// Currently unused because json string includes dashes. "right-down" etc.
// A custom unmarshaller would be needed, or an intermediate type, which is undesirable for this one instance.

// MapRenderOrder :: enum {
//  RightDown,  //"right-down"
//  RightUp,    //"right-up"
//  LeftDown,   //"left-down"
//  LeftUp,     //"left-up"
// }

LayerType :: enum {
	TileLayer,
	ObjectGroup,
	ImageLayer,
	Group,
	tilelayer = TileLayer,
	objectgroup = ObjectGroup,
	imagelayer = ImageLayer,
	group = Group,
}

LayerCompression :: enum {
	None,
	zlib,
	gzip,
	zstd,
}

LayerEncoding :: enum {
	csv,
	base64,
}

ObjectLayerDrawOrder :: enum {
	TopDown,
	Index,
	topdown = TopDown,
	index = Index,
}

GridOrientation :: enum {
	Orthogonal,
	Isometric,
	orthogonal = Orthogonal,
	isometric = Isometric,
}

BlendMode :: enum {
	normal,
	add,
	multiply,
	screen,
	overlay,
	darken,
	lighten,
	color_dodge,
	color_burn,
	hard_light,
	soft_light,
	difference,
	exclusion,
}


// Map describes a Tiled map.
Map :: struct {
	background_color:  string `json:"backgroundcolor"`, // Hex-formatted color (#RRGGBB or #AARRGGBB) (optional).
	class:             string `json:"class"`,
	compression_level: i8 `json:"compressionlevel"`,
	height:            i32 `json:"height"`, // Number of tile rows.
	hex_side_length:   i32 `json:"hexsidelength"`, // Length of the side of a hex tile in pixels.
	infinite:          bool `json:"infinite"`, // Whether the map has infinite dimensions.
	layers:            []Layer `json:"layers"`, // Array of Layers.
	next_layer_id:     i32 `json:"nextlayerid"`, // Auto-increments for each layer.
	next_object_id:    i32 `json:"nextobjectid"`, // Auto-increments for each placed object.
	orientation:       MapOrientation `json:"orientation"`, // "orthogonal", "isometric", "staggered" or "hexagonal".
	parallax_origin_x: f32 `json:"parallaxoriginx"`, // X coordinate of the parallax origin in pixels (since 1.8, default: 0)
	parallax_origin_y: f32 `json:"parallaxoriginy"`, // Y coordinate of the parallax origin in pixels (since 1.8, default: 0)
	properties:        []Property `json:"properties"`, // A list of properties (name, value, type).
	render_order:      string `json:"renderorder"`, // Rendering direction (orthogonal maps only).
	skew_x:            i32 `json:"skewx"`, // skewx X offset applied per tile row (oblique maps only)
	skew_y:            i32 `json:"skewy"`, // skewy Y offset applied per tile column (oblique maps only)
	stagger_axis:      MapStaggerAxis `json:"staggeraxis"`, // "x" or "y" (staggered / hexagonal maps only).
	stagger_index:     string `json:"staggerindex"`, // "odd" or "even" (staggered / hexagonal maps only).
	tiled_version:     string `json:"tiledversion"`, // The Tiled version used to save the file.
	tile_height:       i32 `json:"tileheight"`, // Map grid height.
	tilesets:          []Tileset `json:"tilesets"`, // Array of Tilesets.
	tile_width:        i32 `json:"tilewidth"`, // Map grid width.
	type:              string `json:"type"`, // "map" (since 1.0).
	version:           string `json:"version"`, // The JSON format version (previously a number, saved as string since 1.6)
	width:             i32 `json:"width"`, // Number of tile columns.
}


Layer :: struct {
	chunks:            []Chunk `json:"chunks"`, // Array of chunks (optional, for ininite maps)
	class:             string `json:"name"`,
	compression:       LayerCompression `json:"compression"`, // "zlib", "gzip" or empty (default)
	// data:              []i32 `json:"data"`,
	data:              ArrayOrString `json:"data"`,
	drawOrder:         ObjectLayerDrawOrder `json:"drawOrder"`, // "topdown" (default) or "index"
	encoding:          LayerEncoding `json:"encoding"`, // "csv" (default) or "base64"
	height:            i32 `json:"height"`, // Row count. Same as map height for fixed-size maps
	id:                i32 `json:"id"`, // Incremental id - unique across all layers
	image:             string `json:"image"`, // Image used by this layer
	image_height:      i32 `json:"imageheight"`,
	image_width:       i32 `json:"imagewidth"`,
	layers:            []Layer `json:"layers"`, // Array of layers
	locked:            bool `json:"locked"`,
	mode:              BlendMode `json:"mode"`,
	name:              string `json:"name"`, // Name assigned to this layer
	objects:           []Object `json:"objects"`, // Array of objects. objectgroup only.
	offset_x:          f32 `json:"offsetx"`, // Horizontal layer offset in pixels (default: 0)
	offset_y:          f32 `json:"offsety"`, // Vertical layer offset in pixels (default: 0)
	opacity:           f32 `json:"opacity"`, // Value between 0 and 1
	parallax_x:        Maybe(f32) `json:"parallaxx"`, // Horizontal layer parallax, default to 1
	parallax_y:        Maybe(f32) `json:"parallaxy"`, // Vertical layer parallax, default to 1
	properties:        []Property `json:"properties"`, // A list of properties (name, value, type)
	repeat_x:          bool `json:"repeatx"`,
	repeat_y:          bool `json:"repeaty"`,
	start_x:           i32 `json:"startx"`,
	start_y:           i32 `json:"starty"`,
	tint_color:        string `json:"tintcolor"`,
	transparent_color: string `json:"transparentcolor"`, // Hex-formatted color (#RRGGBB) (optional)
	type:              LayerType `json:"type"`, // "tilelayer, "objectgroup, "imagelayer or "group"
	visible:           bool `json:"visible"`, // Whether layer is shown or hidden in editor
	width:             i32 `json:"width"`, // Column count. Same as map width for fixed-size maps. tilelayer only.
	x:                 i32 `json:"x"`, // Horizontal layer offset in tiles. Always 0
	y:                 i32 `json:"y"`, // Vertical layer offset in tiles. Always 0
}

// Chunk is used to store the tile layer data for infinite maps.
Chunk :: struct {
	data:   ArrayOrString `json:"data"`,
	height: i32 `json:"height"`, // Height in tiles
	width:  i32 `json:"width"`, // Width in tiles
	x:      i32 `json:"x"`, // X coordinate in tiles
	y:      i32 `json:"y"`, // Y coordinate in tiles
}

Object :: struct {
	capsule:    bool `json:"capsule"`,
	ellipse:    bool `json:"ellipse"`, // Used to mark an object as an ellipse
	gid:        i32 `json:"gid"`, // GID, only if object comes from a Tilemap
	height:     f64 `json:"height"`, // Height in pixels, ignored if using a gid
	id:         i32 `json:"id"`, // Incremental id - unique across all objects
	name:       string `json:"name"`, // String assigned to name field in editor
	opacity:    f32 `json:"opacity"`,
	point:      bool `json:"point"`, // Used to mark an object as a point
	polygon:    []Coordinate `json:"polygon"`, // A list of x,y coordinates in pixels
	polyline:   []Coordinate `json:"polyline"`, // A list of x,y coordinates in pixels
	properties: []Property `json:"properties"`, // A list of properties (name, value, type)
	rotation:   f64 `json:"rotation"`, // Angle in degrees clockwise
	template:   string `json:"template"`, // Reference to a template file, in case object is a template instance
	text:       Text `json:"text"`, // String key-value pairs
	type:       string `json:"type"`, // String assigned to type field in editor
	visible:    bool `json:"visible"`, // Whether object is shown in editor
	width:      f64 `json:"width"`, // Width in pixels, ignored if using a gid
	x:          f64 `json:"x"`, // X coordinate in pixels
	y:          f64 `json:"y"`, // Y coordinate in pixels
}

Text :: struct {
	bold:        bool `json:"bold"`, // Whether to use a bold font (default: false)
	color:       string `json:"color"`, // Hex-formatted color (#RRGGBB or #AARRGGBB) (default: #000000)
	font_family: string `json:"fontfamily"`, // Font family (default: sans-serif)
	h_align:     string `json:"halign"`, // Horizontal alignment (center, right, justify or left (default))
	italic:      bool `json:"italic"`, // Whether to use an italic font (default: false)
	kerning:     bool `json:"kerning"`, // Whether to use kerning when placing characters (default: true)
	pixel_size:  i32 `json:"pixelsize"`, // Pixel size of font (default: 16)
	strikeout:   bool `json:"strikeout"`, // Whether to strike out the text (default: false)
	text:        string `json:"text"`, // Text
	underline:   bool `json:"underline"`, // Whether to underline the text (default: false)
	valign:      string `json:"valign"`, // Vertical alignment (center, bottom or top (default))
	wrap:        bool `json:"wrap"`, // Whether the text is wrapped within the object bounds (default: false)
}

Coordinate :: struct {
	x: f32 `json:"x"`,
	y: f32 `json:"y"`,
}

TileOffset :: struct {
	x: i32 `json:"x"`,
	y: i32 `json:"y"`,
}

Transformations :: struct {
	h_flip:               bool `json:"hflip"`, // Tiles can be flipped horizontally
	v_flip:               bool `json:"vflip"`, // Tiles can be flipped vertically
	rotate:               bool `json:"rotate"`, // Tiles can be rotated in 90-degree increments
	prefer_untransformed: bool `json:"preferuntransformed"`, // Whether untransformed tiles remain preferred, otherwise transformed tiles are used to produce more variations
}

// A Tileset that associates information with each tile, like its image
// path or terrain type, may include a Tiles array property. Each tile
// has an ID property, which specifies the local ID within the tileset.
//
// For the terrain information, each value is a length-4 array where
// each element is the index of a terrain on one corner of the tile.
// The order of indices is: top-left, top-right, bottom-left, bottom-right.
Tileset :: struct {
	background_color:  string `json:"backgroundcolor"`,
	class:             string `json:"class"`,
	columns:           i32 `json:"columns"`, // The number of tile columns in the tileset
	fillmode:          string `json:"fillmode"`,
	first_gid:         i32 `json:"firstgid"`, // GID corresponding to the first tile in the set
	grid:              Grid `json:"grid"`, // (Optional) https://doc.mapeditor.org/en/stable/reference/tmx-map-format/#tmx-grid
	image:             string `json:"image"`, // Image used for tiles in this set
	image_height:      i32 `json:"imageheight"`, // Height of source image in pixels
	image_width:       i32 `json:"imagewidth"`, // Width of source image in pixels
	margin:            i32 `json:"margin"`, // Buffer between image edge and first tile (pixels)
	name:              string `json:"name"`, // Name given to this tileset
	object_alignment:  string `json:"objectalignment"`,
	properties:        []Property `json:"properties"`, // A list of properties (name, value, type)
	source:            string `json:"source"`, // Only used if an external tileset is referred to
	spacing:           i32 `json:"spacing"`, // Spacing between adjacent tiles in image (pixels)
	terrains:          []Terrain `json:"terrains"`, // Array of Terrains (optional)
	tile_count:        i32 `json:"tilecount"`, // The number of tiles in this tileset
	tiled_version:     string `json:"tiledversion"`,
	tile_height:       i32 `json:"tileheight"`, // Maximum height of tiles in this set
	tile_offset:       TileOffset `json:"tileoffset"`, // https://doc.mapeditor.org/en/stable/reference/tmx-map-format/#tmx-tileoffset
	tile_render_size:  string `json:"tilerendersize"`,
	tiles:             []Tile `json:"tiles"`, // Array of Tiles (optional)
	tile_width:        i32 `json:"tilewidth"`, // Maximum width of tiles in this set
	transformations:   Transformations `json:"transformations"`,
	transparent_color: string `json:"transparentcolor"`, // Hex-formatted color (#RRGGBB) (optional)
	type:              string `json:"type"`, // "tileset" (for tileset files, since 1.0)
	version:           string `json:"version"`,
	wang_sets:         []WangSet `json:"wangsets"`, // Array of Wang sets (since 1.1.5)
}

// The Grid element is only used in case of isometric orientation,
// and determines how tile overlays for terrain and collision information are rendered.
Grid :: struct {
	height:      i32 `json:"height"`, // Height of a grid cell
	orientation: GridOrientation `json:"orientation"`, // "orthogonal" or "isometric"
	width:       i32 `json:"width"`, // Width of a grid cell
}

Tile :: struct {
	animation:    []Frame `json:"animation"`, // Array of Frames
	id:           i32 `json:"id"`, // Local ID of the tile
	image:        string `json:"image"`, // Image representing this tile (optional)
	image_height: i32 `json:"imageheight"`, // Height of the tile image in pixels
	image_width:  i32 `json:"imagewidth"`, // Width of the tile image in pixels
	x:            i32 `json:"x"`, // The X position of the sub-rectangle representing this tile (default: 0)
	y:            i32 `json:"y"`, // The Y position of the sub-rectangle representing this tile (default: 0)
	width:        i32 `json:"width"`, //   The width of the sub-rectangle representing this tile (defaults to the image width)
	height:       i32 `json:"height"`, //   The height of the sub-rectangle representing this tile (defaults to the image height)
	object_group: Layer `json:"objectgroup"`, // Layer with type "objectgroup" (optional)
	probability:  f32 `json:"probability"`, //  Percentage chance this tile is chosen when competing with others in the editor (default: 1)
	properties:   []Property `json:"properties"`, // A list of properties (name, value, type)
	terrain:      []i32 `json:"terrain"`, //[]WangSet // Index of terrain for each corner of tile
	type:         string `json:"type"`, // The type of the tile (optional)
}

Frame :: struct {
	duration: i32 `json:"duration"`, // Frame duration in milliseconds
	tile_id:  i32 `json:"tileid"`, // Local tile ID representing this frame
}

Property :: struct {
	name:          string `json:"name"`, //Name of the property
	type:          string `json:"type"`, //Type of the property (string (default), int, float, bool, color, file, object or class (since 0.16, with color and file added in 0.17, object added in 1.4 and class added in 1.8))
	property_type: string `json:"propertytype"`, //Name of the custom property type, when applicable (since 1.8)
	value:         Maybe(string) `json:"value"`, //Value of the property
}


Terrain :: struct {
	name:       string `json:"name"`, // Name of terrain
	properties: []Property `json:"properties"`,
	tile:       i32 `json:"tile"`, // Local ID of tile representing terrain
}


WangSet :: struct {
	class:      string `json:"class"`,
	colors:     []WangColor `json:"colors"`, // Array of Wang colors
	name:       string `json:"name"`, // Name of the Wang set
	properties: []Property `json:"properties"`,
	tile:       i32 `json:"tile"`, // Local ID of tile representing the Wang set
	type:       string `json:"type"`,
	wang_tiles: []WangTile `json:"wangtiles"`, // Array of Wang tiles
}

WangColor :: struct {
	class:       string `json:"class"`,
	color:       string `json:"color"`, // Hex-formatted color (#RRGGBB or #AARRGGBB)
	name:        string `json:"name"`, // Name of the Wang color
	probability: f32 `json:"probability"`, // Probability used when randomizing
	properties:  []Property `json:"properties"`,
	tile:        i32 `json:"tile"`, // Local ID of tile representing the Wang color
}

WangTile :: struct {
	tile_id: i32 `json:"tileid"`, // Local ID of tile
	wang_id: [8]byte `json:"wangid"`, // Array of Wang color indexes (uchar[8])
	// d_flip:  bool `json:"dflip"`, // Tile is flipped diagonally
	// h_flip:  bool `json:"hflip"`, // Tile is flipped horizontally
	// v_flip:  bool `json:"vflip"`, // Tile is flipped vertically
}

// An ObjectTemplate is written to its own file
// and referenced by any instances of that template.
ObjectTemplate :: struct {
	type:    string `json:"type"`, // "template"
	tileset: Tileset `json:"tileset"`, // External tileset used by the template (optional)
	object:  Object `json:"object"`, // The object instantiated by this template
}
