extends Node2D

const ARENA := Rect2(60.0, 70.0, 1160.0, 580.0)
const PLAYER_RADIUS := 18.0
const BOMB_RADIUS := 14.0
const BOMB_EXPLOSION_RADIUS := 90.0
const PICKUP_RADIUS := 12.0
const PLAYER_SPEED := 270.0
const DASH_SPEED := 980.0
const MAX_BOMBS := 20
const STARTING_BOMBS := 8
const BOMB_SPAWN_INTERVAL := 0.6
const PICKUP_SPAWN_INTERVAL := 5.0
const PICKUP_TYPES := ["Dash", "Shield"]

const COLORS := {
    "Red": Color(1.0, 0.35, 0.38),
    "Orange": Color(1.0, 0.58, 0.2),
    "Yellow": Color(1.0, 0.82, 0.22),
    "Green": Color(0.26, 0.75, 0.38),
    "Blue": Color(0.22, 0.52, 1.0),
    "Indigo": Color(0.42, 0.33, 0.86),
    "Violet": Color(0.72, 0.38, 0.9)
}

const COLOR_NAMES := ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]

var mode := "solo"
var solo_color := "Blue"
var p1_color := "Red"
var p2_color := "Blue"

var ui_layer: CanvasLayer
var menu_screen: Control
var color_screen: Control
var hud_screen: Control
var result_screen: Control
var timer_label: Label

var players: Array[Dictionary] = []
var bombs: Array[Dictionary] = []
var pickups: Array[Dictionary] = []

var bomb_spawn_timer := 0.0
var pickup_spawn_timer := 0.0
var survival_time := 0.0
var current_state := "menu"
var result_text := ""

func _ready() -> void:
    randomize()
    _build_ui()
    _show_main_menu()

func _build_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    menu_screen = Control.new()
    menu_screen.name = "MenuScreen"
    menu_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(menu_screen)

    color_screen = Control.new()
    color_screen.name = "ColorScreen"
    color_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(color_screen)

    hud_screen = Control.new()
    hud_screen.name = "HUD"
    hud_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(hud_screen)

    result_screen = Control.new()
    result_screen.name = "ResultScreen"
    result_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(result_screen)

    for screen in [menu_screen, color_screen, hud_screen, result_screen]:
        screen.visible = false

func _clear_screen(screen: Control) -> void:
    for child in screen.get_children():
        child.queue_free()

func _make_label(parent: Control, text: String, size: int, color: Color, x: float, y: float) -> Label:
    var label := Label.new()
    label.text = text
    label.position = Vector2(x, y)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _make_button(parent: Control, text: String, x: float, y: float, width: float = 220.0, height: float = 54.0) -> Button:
    var button := Button.new()
    button.text = text
    button.position = Vector2(x, y)
    button.custom_minimum_size = Vector2(width, height)
    button.focus_mode = Control.FOCUS_NONE
    parent.add_child(button)
    return button

func _show_main_menu() -> void:
    current_state = "menu"
    for screen in [menu_screen, color_screen, hud_screen, result_screen]:
        screen.visible = false
    menu_screen.visible = true
    _clear_screen(menu_screen)

    var title := _make_label(menu_screen, "BOMB DODGE", 54, Color(0.9, 0.94, 1.0), 440.0, 110.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(400.0, 60.0)

    var solo_button := _make_button(menu_screen, "Solo", 540.0, 280.0)
    solo_button.pressed.connect(func() -> void:
        mode = "solo"
        _show_color_screen()
    )

    var multi_button := _make_button(menu_screen, "Local Multiplayer", 500.0, 360.0, 280.0, 54.0)
    multi_button.pressed.connect(func() -> void:
        mode = "local"
        _show_color_screen()
    )

    var exit_button := _make_button(menu_screen, "Exit", 540.0, 440.0)
    exit_button.pressed.connect(func() -> void:
        get_tree().quit()
    )

func _show_color_screen() -> void:
    current_state = "color_select"
    for screen in [menu_screen, color_screen, hud_screen, result_screen]:
        screen.visible = false
    color_screen.visible = true
    _clear_screen(color_screen)

    _ensure_unique_colors()

    var title := _make_label(color_screen, "Choose Colors", 40, Color(0.92, 0.96, 1.0), 480.0, 60.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(320.0, 50.0)

    if mode == "solo":
        var panel := _build_color_panel(color_screen, "Solo Player", 0)
        panel.position = Vector2(420.0, 160.0)

        var start_button := _make_button(color_screen, "Start", 540.0, 560.0, 200.0, 54.0)
        start_button.pressed.connect(_start_game)
    else:
        var p1_panel := _build_color_panel(color_screen, "Player 1", 0)
        p1_panel.position = Vector2(260.0, 180.0)

        var p2_panel := _build_color_panel(color_screen, "Player 2", 1)
        p2_panel.position = Vector2(760.0, 180.0)

        var start_button := _make_button(color_screen, "Start", 540.0, 560.0, 200.0, 54.0)
        start_button.pressed.connect(_start_game)

func _build_color_panel(parent: Control, label_text: String, slot: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(220.0, 160.0)
    parent.add_child(panel)

    var vbox := VBoxContainer.new()
    panel.add_child(vbox)

    var title := _make_label(vbox, label_text, 22, Color(0.95, 0.98, 1.0), 0.0, 0.0)
    title.custom_minimum_size = Vector2(220.0, 32.0)

    var current_color := solo_color
    if mode == "local":
        current_color = p1_color if slot == 0 else p2_color

    _make_label(vbox, "Selected: " + current_color, 18, Color(0.8, 0.9, 1.0), 0.0, 0.0)

    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(row)

    for color_name in COLOR_NAMES:
        var button := _make_button(row, color_name, 0.0, 0.0, 80.0, 40.0)
        button.modulate = COLORS[color_name]
        button.disabled = _is_color_taken_by_other(color_name, slot)
        button.pressed.connect(func() -> void:
            _set_player_color(slot, color_name)
        )

    return panel

func _is_color_taken_by_other(color_name: String, slot: int) -> bool:
    if mode == "solo":
        return false
    if slot == 0:
        return color_name == p2_color
    return color_name == p1_color

func _set_player_color(slot: int, color_name: String) -> void:
    if mode == "solo":
        solo_color = color_name
    elif slot == 0:
        p1_color = color_name
    else:
        p2_color = color_name

    _ensure_unique_colors()
    if current_state == "color_select":
        _show_color_screen()

func _ensure_unique_colors() -> void:
    if mode == "local" and p1_color == p2_color:
        p2_color = _next_available_color(p1_color)

func _next_available_color(excluded: String) -> String:
    for color_name in COLOR_NAMES:
        if color_name != excluded:
            return color_name
    return excluded

func _start_game() -> void:
    current_state = "playing"
    players.clear()
    bombs.clear()
    pickups.clear()
    bomb_spawn_timer = 0.0
    pickup_spawn_timer = 0.0
    survival_time = 0.0
    result_text = ""

    for screen in [menu_screen, color_screen, result_screen]:
        screen.visible = false
    hud_screen.visible = true
    _clear_screen(hud_screen)

    if mode == "solo":
        players.append(_create_player("P1", solo_color, Vector2(160.0, 360.0)))
    else:
        players.append(_create_player("P1", p1_color, Vector2(180.0, 250.0)))
        players.append(_create_player("P2", p2_color, Vector2(180.0, 470.0)))

    for i in range(STARTING_BOMBS):
        _spawn_bomb()

    _build_hud()

func _create_player(name: String, color_name: String, position: Vector2) -> Dictionary:
    return {
        "name": name,
        "color": color_name,
        "position": position,
        "speed": PLAYER_SPEED,
        "move_dir": Vector2.ZERO,
        "dash_timer": 0.0,
        "dash_direction": Vector2.ZERO,
        "dash_ready": false,
        "shield_timer": 0.0,
        "shield_ready": false,
        "last_click_ms": 0,
        "dead": false,
        "hud_button": null
    }

func _build_hud() -> void:
    var timer_title := _make_label(hud_screen, "Survival Time:", 24, Color(0.85, 0.9, 1.0), 510.0, 10.0)
    _ = timer_title
    timer_label = _make_label(hud_screen, "00.0s", 28, Color(1.0, 1.0, 1.0), 565.0, 38.0)

    for index: int in range(players.size()):
        var player: Dictionary = players[index]
        var label_x: float = 30.0 + index * 320.0
        _make_label(hud_screen, player["name"], 22, COLORS[player["color"]], label_x, 18.0)

        var button := Button.new()
        button.position = Vector2(label_x, 52.0)
        button.custom_minimum_size = Vector2(70.0, 40.0)
        button.focus_mode = Control.FOCUS_NONE
        button.visible = false
        button.text = ""
        button.pressed.connect(func() -> void:
            _activate_ability(player)
        )
        hud_screen.add_child(button)
        player["hud_button"] = button

func _activate_ability(player: Dictionary) -> void:
    var now_ms := Time.get_ticks_msec()
    var double_click := now_ms - int(player["last_click_ms"]) < 300
    player["last_click_ms"] = now_ms

    if not double_click:
        return

    if player["color"] == "Red" and player["dash_ready"]:
        player["dash_ready"] = false
        player["dash_timer"] = 0.18
        if player["move_dir"].length() > 0.0:
            player["dash_direction"] = player["move_dir"]
        else:
            player["dash_direction"] = Vector2.RIGHT

    elif player["color"] == "Blue" and player["shield_ready"]:
        player["shield_ready"] = false
        player["shield_timer"] = 10.0

func _process(delta: float) -> void:
    if current_state != "playing":
        return

    survival_time += delta
    timer_label.text = str(snapped(survival_time, 0.1)) + "s"

    bomb_spawn_timer += delta
    if bombs.size() < MAX_BOMBS and bomb_spawn_timer >= BOMB_SPAWN_INTERVAL:
        _spawn_bomb()
        bomb_spawn_timer = 0.0

    pickup_spawn_timer += delta
    if pickup_spawn_timer >= PICKUP_SPAWN_INTERVAL:
        _spawn_pickup()
        pickup_spawn_timer = 0.0

    for player: Dictionary in players:
        if player["dead"]:
            continue

        _update_player_movement(player, delta)

        if player["dash_timer"] > 0.0:
            player["dash_timer"] = max(0.0, player["dash_timer"] - delta)
        if player["shield_timer"] > 0.0:
            player["shield_timer"] = max(0.0, player["shield_timer"] - delta)

    for bomb: Dictionary in bombs:
        bomb["time_left"] -= delta
        if bomb["time_left"] <= 0.0:
            _explode_bomb(bomb)

    for pickup: Dictionary in pickups:
        for player: Dictionary in players:
            if player["dead"]:
                continue
            if player["position"].distance_to(pickup["position"]) <= PLAYER_RADIUS + PICKUP_RADIUS:
                if pickup["type"] == "Dash" and player["color"] == "Red":
                    player["dash_ready"] = true
                    pickups.erase(pickup)
                    break
                if pickup["type"] == "Shield" and player["color"] == "Blue":
                    player["shield_ready"] = true
                    pickups.erase(pickup)
                    break

    _update_ability_hud()
    _check_game_end()
    queue_redraw()

func _update_player_movement(player: Dictionary, delta: float) -> void:
    var move := Vector2.ZERO

    if player["name"] == "P1":
        if Input.is_physical_key_pressed(KEY_W): move.y -= 1.0
        if Input.is_physical_key_pressed(KEY_S): move.y += 1.0
        if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0
        if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
    else:
        if Input.is_physical_key_pressed(KEY_UP): move.y -= 1.0
        if Input.is_physical_key_pressed(KEY_DOWN): move.y += 1.0
        if Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1.0
        if Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1.0

    if move.length() > 0.0:
        move = move.normalized()
        player["move_dir"] = move

    if player["dash_timer"] > 0.0:
        player["position"] += player["dash_direction"] * DASH_SPEED * delta
    else:
        player["position"] += move * PLAYER_SPEED * delta

    player["position"] = _clamp_to_arena(player["position"], PLAYER_RADIUS)

func _clamp_to_arena(position: Vector2, radius: float) -> Vector2:
    var min_x := ARENA.position.x + radius
    var max_x := ARENA.position.x + ARENA.size.x - radius
    var min_y := ARENA.position.y + radius
    var max_y := ARENA.position.y + ARENA.size.y - radius
    return Vector2(clamp(position.x, min_x, max_x), clamp(position.y, min_y, max_y))

func _spawn_bomb() -> void:
    if bombs.size() >= MAX_BOMBS:
        return

    var position := _find_valid_bomb_position()
    bombs.append({
        "position": position,
        "time_left": randf_range(2.0, 3.0),
        "radius": BOMB_RADIUS,
        "explosion_radius": BOMB_EXPLOSION_RADIUS,
    })

func _find_valid_bomb_position() -> Vector2:
    for attempt: int in range(200):
        var x := randf_range(ARENA.position.x + 60.0, ARENA.position.x + ARENA.size.x - 60.0)
        var y := randf_range(ARENA.position.y + 60.0, ARENA.position.y + ARENA.size.y - 60.0)
        var candidate := Vector2(x, y)

        var safe := true
        for player: Dictionary in players:
            if candidate.distance_to(player["position"]) < 80.0:
                safe = false
                break

        if safe:
            return candidate

    return Vector2(ARENA.position.x + 120.0, ARENA.position.y + 120.0)

func _spawn_pickup() -> void:
    var valid_types: Array[String] = []
    for player: Dictionary in players:
        if player["color"] == "Red":
            valid_types.append("Dash")
        if player["color"] == "Blue":
            valid_types.append("Shield")

    if valid_types.is_empty():
        return

    var pickup_type: String = valid_types[randi() % valid_types.size()]
    var position := Vector2(
        randf_range(ARENA.position.x + 80.0, ARENA.position.x + ARENA.size.x - 80.0),
        randf_range(ARENA.position.y + 80.0, ARENA.position.y + ARENA.size.y - 80.0)
    )

    pickups.append({
        "type": pickup_type,
        "position": position,
        "radius": PICKUP_RADIUS,
        "color": Color(1.0, 0.28, 0.28) if pickup_type == "Dash" else Color(0.2, 0.55, 1.0)
    })

func _explode_bomb(bomb: Dictionary) -> void:
    bombs.erase(bomb)

    for player: Dictionary in players:
        if player["dead"]:
            continue
        if player["shield_timer"] > 0.0:
            continue
        if player["position"].distance_to(bomb["position"]) <= bomb["explosion_radius"]:
            player["dead"] = true

func _update_ability_hud() -> void:
    for player: Dictionary in players:
        var button: Button = player["hud_button"]
        if button == null:
            continue

        if player["color"] == "Red":
            if player["dash_ready"]:
                button.text = "Dash"
                button.visible = true
                button.modulate = Color(1.0, 0.3, 0.3)
            elif player["dash_timer"] > 0.0:
                button.text = "D!"
                button.visible = true
                button.modulate = Color(1.0, 0.7, 0.7)
            else:
                button.visible = false
        elif player["color"] == "Blue":
            if player["shield_ready"]:
                button.text = "Shield"
                button.visible = true
                button.modulate = Color(0.28, 0.54, 1.0)
            elif player["shield_timer"] > 0.0:
                button.text = "S!"
                button.visible = true
                button.modulate = Color(0.5, 0.8, 1.0)
            else:
                button.visible = false
        else:
            button.visible = false

func _check_game_end() -> void:
    var alive: Array[Dictionary] = []
    for player: Dictionary in players:
        if not player["dead"]:
            alive.append(player)

    if mode == "solo":
        if alive.is_empty():
            result_text = "You were eliminated!\nFinal Time: " + str(snapped(survival_time, 0.1)) + "s"
            _show_result_screen()
        elif alive.size() == 1:
            result_text = "You survived!\nFinal Time: " + str(snapped(survival_time, 0.1)) + "s"
            _show_result_screen()
    else:
        if alive.size() <= 1:
            if alive.size() == 1:
                result_text = alive[0]["name"] + " wins!\nFinal Time: " + str(snapped(survival_time, 0.1)) + "s"
            else:
                result_text = "Draw!\nFinal Time: " + str(snapped(survival_time, 0.1)) + "s"
            _show_result_screen()

func _show_result_screen() -> void:
    current_state = "result"
    for screen in [menu_screen, color_screen, hud_screen]:
        screen.visible = false
    result_screen.visible = true
    _clear_screen(result_screen)

    var title := _make_label(result_screen, "Result", 42, Color(0.95, 0.97, 1.0), 520.0, 120.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(240.0, 50.0)

    var result_label := _make_label(result_screen, result_text, 28, Color(1.0, 1.0, 1.0), 370.0, 210.0)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.custom_minimum_size = Vector2(540.0, 120.0)

    var restart_button := _make_button(result_screen, "Restart", 430.0, 420.0, 180.0, 54.0)
    restart_button.pressed.connect(func() -> void:
        _show_color_screen()
    )

    var main_menu_button := _make_button(result_screen, "Main Menu", 670.0, 420.0, 180.0, 54.0)
    main_menu_button.pressed.connect(_show_main_menu)

func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.03, 0.08, 0.20))
    draw_rect(ARENA, Color(0.08, 0.12, 0.28), false, 3.0)

    for bomb: Dictionary in bombs:
        var color := Color(1.0, 0.62, 0.25)
        if bomb["time_left"] <= 1.0:
            color = Color(1.0, 0.35, 0.15)
        draw_circle(bomb["position"], bomb["radius"], color)
        draw_arc(bomb["position"], bomb["radius"] + 4.0, 0.0, TAU, 12, Color(1.0, 0.85, 0.7, 0.8), 1.5)

    for pickup: Dictionary in pickups:
        draw_circle(pickup["position"], pickup["radius"], pickup["color"])
        draw_arc(pickup["position"], pickup["radius"] + 3.0, 0.0, TAU, 10, Color(1.0, 1.0, 1.0, 0.7), 2.0)

    for player: Dictionary in players:
        if player["dead"]:
            continue
        draw_circle(player["position"], PLAYER_RADIUS, COLORS[player["color"]])
        draw_circle(player["position"], PLAYER_RADIUS + 3.0, Color(0.13, 0.14, 0.18, 0.2), false, 2.0)
        if player["shield_timer"] > 0.0:
            draw_circle(player["position"], PLAYER_RADIUS + 10.0, Color(0.34, 0.74, 1.0, 0.25), false, 2.0)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and current_state == "playing":
        _show_main_menu()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        get_tree().quit()
