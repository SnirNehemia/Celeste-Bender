class_name TouchTuning
extends Resource
## Every number that shapes the on-screen TOUCH controls lives here: sizes, gaps,
## see-through amounts, the d-pad's dead zone. The touch twin of PlayerTuning:
## TouchControls (autoload/touch_controls.gd) loads resources/touch_tuning.tres and
## reads it fresh every frame, so edits take effect at once.
##
## Units are GAME pixels (the 320x180 screen). On a 1080 px tall phone one game pixel
## is 6 phone pixels, about 0.4 mm, so a 26 px button is roughly 1 cm across.

@export_group("Showing")
## Show the controls even without a touchscreen (to try the layout on the PC with
## the mouse... which only works if the mouse sends touches: Project Settings >
## Input Devices > Pointing > Emulate Touch From Mouse).
@export var show_without_touchscreen: bool = false
## How opaque a button's outline and label are when not pressed (0 = invisible).
@export_range(0.0, 1.0) var idle_alpha: float = 0.35
## How opaque a button's fill is while pressed.
@export_range(0.0, 1.0) var pressed_alpha: float = 0.45

@export_group("Buttons (left side)")
## Width and height of one action button.
@export var button_size: float = 26.0
## Space between two buttons. Touches in the gap count for the nearer button, so
## there are no dead spots between them.
@export var button_gap: float = 3.0
## Distance from the screen's left and bottom edges to the grid.
@export var button_margin: float = 4.0
## Font size of the labels on the buttons.
@export var label_font_size: int = 8

@export_group("D-pad (right side)")
## Radius of the d-pad's ring.
@export var dpad_radius: float = 30.0
## Distance from the screen's right and bottom edges to the ring.
@export var dpad_margin: float = 6.0
## Inside this share of the radius the d-pad presses nothing, so a resting thumb
## doesn't walk.
@export_range(0.0, 1.0) var dpad_dead_zone: float = 0.25
## A direction counts once the thumb's offset leans past this along its axis
## (cos of 67.5 deg = 0.383 gives 8 equal 45 deg slices: 4 straight, 4 diagonal).
## Higher = narrower diagonals.
@export_range(0.0, 1.0) var dpad_axis_threshold: float = 0.383
## Touches that start this far left of the screen's right edge still go to the
## d-pad (measured in game pixels), so the thumb doesn't have to hit the ring itself.
@export var dpad_capture_width: float = 140.0

@export_group("Small buttons (top right)")
## Width and height of the pause / restart / full-screen buttons.
@export var small_button_size: float = 16.0
## Space between them and from the screen's top and right edges.
@export var small_button_gap: float = 4.0
