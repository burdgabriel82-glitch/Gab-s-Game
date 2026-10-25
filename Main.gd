extends Node2D

const ARENA_RECT := Rect2(40.0, 60.0, 1200.0, 600.0)
const PLAYER_RADIUS := 18.0
const BOMB_RADIUS := 14.0
const PICKUP_RADIUS := 12.0
const MAX_BOMBS := 20
const INITIAL_BOMBS := 8
const BOMB_SPAWN_INTERVAL := 0.6
const PICKUP_SPAWN_INTERVAL := 5.0
const COLOR_NAMES := ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]
const COLORS := {
    "Red": Color(1.0, 0.34, 0.38),
    "Orange": Color(1.0, 0.57, 0.18),
    "Yellow": Color(1.0, 0.82, 0.22),
    "Green": Color(0.26, 0.76, 0.38),
    "Blue": Color(0.22, 0.52, 1.0),
    "Indigo": Color(0.42, 0.34, 0.86),
    "Violet": Color(0.72, 0.38, 0.9)
}

var mode := "solo"
var solo_color := "Blue"
var p1_color := "Red"
var p2_color := "Blue"

var ui_layer: CanvasLayer
var menu_screen: Control
var color_screen: Control
var hud: Control
var result_screen: Control

var timer_label: Label
var main_title_label: Label

var players: Array = []
var bombs: Array = []
var pickups: Array = []
var bomb_spawn_timer := 0.0
var pickup_spawn_timer := 0.0
var current_state := "menu"
var total_time := 0.0
var final_result := ""

func _ready() -> void:
    randomize()
    build_ui()
    show_main_menu()

func build_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    menu_screen = Control.new(); menu_screen.name = "MenuScreen"; menu_screen.set_anchors_preset(Control.PRESET_FULL_RECT); ui_layer.add_child(menu_screen)
    color_screen = Control.new(); color_screen.name = "ColorScreen"; color_screen.set_anchors_preset(Control.PRESET_FULL_RECT); ui_layer.add_child(color_screen)
    hud = Control.new(); hud.name = "HUD"; hud.set_anchors_preset(Control.PRESET_FULL_RECT); ui_layer.add_child(hud)
    result_screen = Control.new(); result_screen.name = "ResultScreen"; result_screen.set_anchors_preset(Control.PRESET_FULL_RECT); ui_layer.add_child(result_screen)

    for screen in [menu_screen, color_screen, hud, result_screen]:
        screen.visible = false

func clear_screen(screen: Control) -> void:
    var children := screen.get_children()
    for child in children:
        child.queue_free()

func create_label(parent: Control, text: String, size: int = 24, color: Color = Color.WHITE, x: float = 0.0, y: float = 0.0) -> Label:
    var label := Label.new()
    label.text = text
    label.position = Vector2(x, y)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func create_button(parent: Control, text: String, x: float, y: float, w: float = 220.0, h: float = 54.0) -> Button:
    var button := Button.new()
    button.text = text
    button.position = Vector2(x, y)
    button.custom_minimum_size = Vector2(w, h)
    button.focus_mode = Control.FOCUS_NONE
    parent.add_child(button)
    return button

func show_main_menu() -> void:
    current_state = "menu"
    clear_screen(menu_screen)
    clear_screen(color_screen)
    clear_screen(hud)
    clear_screen(result_screen)

    menu_screen.visible = true
    color_screen.visible = false
    hud.visible = false
    result_screen.visible = false

    var title := create_label(menu_screen, "BOMB DODGE", 54, Color(0.90, 0.94, 1.0), 440.0, 110.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(400.0, 60.0)

    var solo_button := create_button(menu_screen, "Solo", 540.0, 280.0)
    solo_button.pressed.connect(func() -> void:
        mode = "solo"
        show_color_screen()
    )

    var multi_button := create_button(menu_screen, "Local Multiplayer", 500.0, 360.0, 280.0, 54.0)
    multi_button.pressed.connect(func() -> void:
        mode = "local"
        show_color_screen()
    )

    var exit_button := create_button(menu_screen, "Exit", 540.0, 440.0)
    exit_button.pressed.connect(func() -> void:
        get_tree().quit()
    )

func show_color_screen() -> void:
    current_state = "color_select"
    clear_screen(color_screen)
    color_screen.visible = true
    menu_screen.visible = false
    hud.visible = false
    result_screen.visible = false

    ensure_unique_colors()

    var title := create_label(color_screen, "Choose Colors", 40, Color(0.92, 0.96, 1.0), 480.0, 60.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(320.0, 50.0)

    if mode == "solo":
        var panel := create_player_color_panel(color_screen, "Solo Player", 1, 0, 220.0, 160.0, 0.0)
        panel.position = Vector2(420.0, 160.0)
        var start_button := create_button(color_screen, "Start", 540.0, 560.0, 200.0, 54.0)
        start_button.pressed.connect(start_game)
    else:
        var p1_panel := create_player_color_panel(color_screen, "Player 1", 0, 0, 220.0, 160.0, 0.0)
        p1_panel.position = Vector2(260.0, 180.0)

        var p2_panel := create_player_color_panel(color_screen, "Player 2", 1, 1, 220.0, 160.0, 0.0)
        p2_panel.position = Vector2(760.0, 180.0)

        var start_button := create_button(color_screen, "Start", 540.0, 560.0, 200.0, 54.0)
        start_button.pressed.connect(start_game)

func create_player_color_panel(parent: Control, label_text: String, player_slot: int, selected_index: int, width: float, height: float, y_offset: float) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.position = Vector2(0.0, y_offset)
    panel.custom_minimum_size = Vector2(width, height)
    parent.add_child(panel)

    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(box)

    var title_label := create_label(box, label_text, 22, Color(0.95, 0.98, 1.0), 0.0, 0.0)
    title_label.custom_minimum_size = Vector2(width, 32.0)

    var current_label := create_label(box, "Selected: " + (player_slot == 0 and mode == "solo" ? solo_color : (player_slot == 0 ? p1_color : p2_color)), 18, Color(0.8, 0.9, 1.0), 0.0, 0.0)
    current_label.name = "CurrentLabel"

    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(row)

    for color_name in COLOR_NAMES:
        var color_button := create_button(row, color_name, 0.0, 0.0, 82.0, 40.0)
        color_button.pressed.connect(func() -> void:
            set_player_color(player_slot, color_name)
        )

        color_button.modulate = COLORS[color_name]
        color_button.disabled = is_color_taken_by_other(color_name, player_slot)

    return panel

func set_player_color(player_slot: int, new_color: String) -> void:
    if mode == "solo":
        solo_color = new_color
    elif player_slot == 0:
        p1_color = new_color
    else:
        p2_color = new_color

    ensure_unique_colors()
    refresh_color_screen()

func ensure_unique_colors() -> void:
    if mode == "local":
        if p1_color == p2_color:
            var next_color := pick_next_available_color(p1_color)
            p2_color = next_color

func pick_next_available_color(excluded: String) -> String:
    for color_name in COLOR_NAMES:
        if color_name != excluded:
            return color_name
    return excluded

func is_color_taken_by_other(color_name: String, player_slot: int) -> bool:
    if mode == "solo":
        return false
    if player_slot == 0:
        return color_name == p2_color
    return color_name == p1_color

func refresh_color_screen() -> void:
    if current_state == "color_select":
        show_color_screen()

func start_game() -> void:
    current_state = "playing"
    players.clear()
    bombs.clear()
    pickups.clear()
    bomb_spawn_timer = 0.0
    pickup_spawn_timer = 0.0
    total_time = 0.0

    clear_screen(hud)
    hud.visible = true
    menu_screen.visible = false
    color_screen.visible = false
    result_screen.visible = false

    if mode == "solo":
        players.append(create_player("P1", solo_color, Vector2(150.0, 360.0)))
    else:
        players.append(create_player("P1", p1_color, Vector2(180.0, 250.0)))
        players.append(create_player("P2", p2_color, Vector2(180.0, 470.0)))

    for index in range(INITIAL_BOMBS):
        spawn_bomb()

    build_hud()
    queue_redraw()

func create_player(name: String, color_name: String, pos: Vector2) -> Dictionary:
    return {
        "name": name,
        "color": color_name,
        "pos": pos,
        "speed": 310.0,
        "move_dir": Vector2.RIGHT,
        "dash_timer": 0.0,
        "dash_direction": Vector2.RIGHT,
        "dash_collected": false,
        "shield_timer": 0.0,
        "shield_collected": false,
        "last_ability_click_ms": 0,
        "dead": false,
        "hud_icon": null,
        "hud_label": null
    }

func build_hud() -> void:
    var timer_title := create_label(hud, "Survival Time:", 24, Color(0.85, 0.9, 1.0), 515.0, 8.0)
    timer_label = create_label(hud, "00.0s", 28, Color(1.0, 1.0, 1.0), 565.0, 36.0)

    for player_index in range(players.size()):
        var player := players[player_index]
        var label_x := 30.0 + (player_index * 320.0)
        var name_label := create_label(hud, player["name"], 22, COLORS[player["color"]], label_x, 18.0)
        player["hud_label"] = name_label

        var icon := Button.new()
        icon.position = Vector2(label_x, 52.0)
        icon.custom_minimum_size = Vector2(70.0, 40.0)
        icon.focus_mode = Control.FOCUS_NONE
        icon.text = ""
        icon.visible = false
        hud.add_child(icon)
        player["hud_icon"] = icon

        icon.pressed.connect(func() -> void:
            on_ability_icon_pressed(player)
        )

func on_ability_icon_pressed(player: Dictionary) -> void:
    var now := Time.get_ticks_msec()
    var is_double_click := now - int(player["last_ability_click_ms"]) < 300
    player["last_ability_click_ms"] = now

    if is_double_click:
        if player["color"] == "Red" and player["dash_collected"]:
            player["dash_collected"] = false
            player["dash_timer"] = 0.18
            player["dash_direction"] = player["move_dir"] if player["move_dir"].length() > 0.0 else Vector2.RIGHT
        elif player["color"] == "Blue" and player["shield_collected"]:
            player["shield_collected"] = false
            player["shield_timer"] = 10.0

func _process(delta: float) -> void:
    if current_state != "playing":
        return

    total_time += delta
    timer_label.text = str(stepify(total_time, 0.1)) + "s"

    bomb_spawn_timer += delta
    if bombs.size() < MAX_BOMBS and bomb_spawn_timer >= BOMB_SPAWN_INTERVAL:
        spawn_bomb()
        bomb_spawn_timer = 0.0

    pickup_spawn_timer += delta
    if pickup_spawn_timer >= PICKUP_SPAWN_INTERVAL:
        spawn_pickup()
        pickup_spawn_timer = 0.0

    for player in players:
        if player["dead"]:
            continue
        update_player_movement(player, delta)
        if player["shield_timer"] > 0.0:
            player["shield_timer"] = max(0.0, player["shield_timer"] - delta)
        if player["dash_timer"] > 0.0:
            player["dash_timer"] = max(0.0, player["dash_timer"] - delta)

    for bomb in bombs:
        bomb["countdown"] -= delta
        if bomb["countdown"] <= 0.0:
            detonate_bomb(bomb)

    for pickup in pickups:
        for player in players:
            if player["dead"]:
                continue
            if player["pos"].distance_to(pickup["pos"]) <= PLAYER_RADIUS + PICKUP_RADIUS:
                if pickup["type"] == "Dash" and player["color"] == "Red":
                    player["dash_collected"] = true
                    pickups.erase(pickup)
                    break
                if pickup["type"] == "Shield" and player["color"] == "Blue":
                    player["shield_collected"] = true
                    pickups.erase(pickup)
                    break

    update_hud_icons()
    check_game_over()
    queue_redraw()

func update_player_movement(player: Dictionary, delta: float) -> void:
    var move_vec := Vector2.ZERO

    if player["name"] == "P1":
        if Input.is_physical_key_pressed(KEY_W):
            move_vec.y -= 1.0
        if Input.is_physical_key_pressed(KEY_S):
            move_vec.y += 1.0
        if Input.is_physical_key_pressed(KEY_A):
            move_vec.x -= 1.0
        if Input.is_physical_key_pressed(KEY_D):
            move_vec.x += 1.0
    else:
        if Input.is_physical_key_pressed(KEY_UP):
            move_vec.y -= 1.0
        if Input.is_physical_key_pressed(KEY_DOWN):
            move_vec.y += 1.0
        if Input.is_physical_key_pressed(KEY_LEFT):
            move_vec.x -= 1.0
        if Input.is_physical_key_pressed(KEY_RIGHT):
            move_vec.x += 1.0

    if move_vec.length() > 0.0:
        move_vec = move_vec.normalized()
        player["move_dir"] = move_vec

    if player["dash_timer"] > 0.0:
        player["pos"] += player["dash_direction"] * 950.0 * delta
    else:
        player["pos"] += move_vec * player["speed"] * delta

    player["pos"] = clamp_to_arena(player["pos"], PLAYER_RADIUS)

func clamp_to_arena(pos: Vector2, radius: float) -> Vector2:
    var min_x := ARENA_RECT.position.x + radius
    var max_x := ARENA_RECT.position.x + ARENA_RECT.size.x - radius
    var min_y := ARENA_RECT.position.y + radius
    var max_y := ARENA_RECT.position.y + ARENA_RECT.size.y - radius
    return Vector2(clamp(pos.x, min_x, max_x), clamp(pos.y, min_y, max_y))

func spawn_bomb() -> void:
    var pos := find_valid_bomb_position()
    bombs.append({
        "pos": pos,
        "countdown": randf_range(2.0, 3.0),
        "radius": BOMB_RADIUS,
        "warning": false
    })

func find_valid_bomb_position() -> Vector2:
    for attempt in range(200):
        var x := randf_range(ARENA_RECT.position.x + 60.0, ARENA_RECT.position.x + ARENA_RECT.size.x - 60.0)
        var y := randf_range(ARENA_RECT.position.y + 60.0, ARENA_RECT.position.y + ARENA_RECT.size.y - 60.0)
        var pos := Vector2(x, y)
        var safe := true
        for player in players:
            if pos.distance_to(player["pos"]) < 80.0:
                safe = false
                break
        if safe:
            return pos
    return Vector2(ARENA_RECT.position.x + 100.0, ARENA_RECT.position.y + 100.0)

func spawn_pickup() -> void:
    if players.is_empty():
        return

    var possible_types := []
    for player in players:
        if player["color"] == "Red":
            possible_types.append("Dash")
        if player["color"] == "Blue":
            possible_types.append("Shield")
    if possible_types.is_empty():
        return

    var pickup_type := possible_types[randi() % possible_types.size()]
    var color := Color(0.92, 0.23, 0.28) if pickup_type == "Dash" else Color(0.16, 0.52, 1.0)

    var pos := Vector2(
        randf_range(ARENA_RECT.position.x + 80.0, ARENA_RECT.position.x + ARENA_RECT.size.x - 80.0),
        randf_range(ARENA_RECT.position.y + 80.0, ARENA_RECT.position.y + ARENA_RECT.size.y - 80.0)
    )

    pickups.append({
        "type": pickup_type,
        "pos": pos,
        "color": color,
        "radius": PICKUP_RADIUS
    })

func detonate_bomb(bomb: Dictionary) -> void:
    bombs.erase(bomb)

    for player in players:
        if player["dead"]:
            continue
        if player["shield_timer"] > 0.0:
            continue
        if player["pos"].distance_to(bomb["pos"]) <= 90.0:
            player["dead"] = true

func check_game_over() -> void:
    var alive_players := []
    for player in players:
        if not player["dead"]:
            alive_players.append(player)

    if mode == "solo":
        if alive_players.size() == 0:
            final_result = "You were eliminated!\nFinal Time: %.1fs" % total_time
            show_result_screen()
        elif alive_players.size() == 1:
            final_result = "You survived!\nFinal Time: %.1fs" % total_time
            show_result_screen()
    else:
        if alive_players.size() <= 1:
            if alive_players.size() == 1:
                final_result = alive_players[0]["name"] + " wins!\nFinal Time: %.1fs" % total_time
            else:
                final_result = "Draw!\nFinal Time: %.1fs" % total_time
            show_result_screen()

func show_result_screen() -> void:
    current_state = "result"
    clear_screen(result_screen)
    result_screen.visible = true
    menu_screen.visible = false
    color_screen.visible = false
    hud.visible = false

    var title := create_label(result_screen, "Result", 42, Color(0.95, 0.97, 1.0), 520.0, 120.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(240.0, 50.0)

    var result_label := create_label(result_screen, final_result, 28, Color(1.0, 1.0, 1.0), 370.0, 210.0)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.custom_minimum_size = Vector2(540.0, 120.0)

    var restart_button := create_button(result_screen, "Restart", 430.0, 420.0, 180.0, 54.0)
    restart_button.pressed.connect(func() -> void:
        if mode == "solo":
            show_color_screen()
        else:
            show_color_screen()
    )

    var main_menu_button := create_button(result_screen, "Main Menu", 670.0, 420.0, 180.0, 54.0)
    main_menu_button.pressed.connect(show_main_menu)

func update_hud_icons() -> void:
    if timer_label == null:
        return

    for player in players:
        if player["hud_icon"] == null:
            continue

        var icon: Button = player["hud_icon"]
        if player["color"] == "Red":
            if player["dash_collected"]:
                icon.text = "Dash"
                icon.visible = true
                icon.modulate = Color(1.0, 0.28, 0.28)
            elif player["dash_timer"] > 0.0:
                icon.text = "D!"
                icon.visible = true
                icon.modulate = Color(1.0, 0.7, 0.7)
            else:
                icon.visible = false
        elif player["color"] == "Blue":
            if player["shield_collected"]:
                icon.text = "Shield"
                icon.visible = true
                icon.modulate = Color(0.28, 0.54, 1.0)
            elif player["shield_timer"] > 0.0:
                icon.text = "S!"
                icon.visible = true
                icon.modulate = Color(0.5, 0.8, 1.0)
            else:
                icon.visible = false
        else:
            icon.visible = false

func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.03, 0.08, 0.20))
    draw_rect(ARENA_RECT, Color(0.08, 0.12, 0.28), false, 3.0)

    for bomb in bombs:
        var color := Color(1.0, 0.62, 0.25)
        if bomb["countdown"] <= 1.0:
            color = Color(1.0, 0.35, 0.15)
        draw_circle(bomb["pos"], bomb["radius"], color)
        draw_arc(bomb["pos"], bomb["radius"] + 4.0, 0.0, TAU, 12, Color(1.0, 0.85, 0.7, 0.8), 1.5)

    for pickup in pickups:
        draw_circle(pickup["pos"], pickup["radius"], pickup["color"])
        draw_arc(pickup["pos"], pickup["radius"] + 3.0, 0.0, TAU, 10, Color(1.0, 1.0, 1.0, 0.7), 2.0)

    for player in players:
        if player["dead"]:
            continue
        var base_color := COLORS[player["color"]]
        draw_circle(player["pos"], PLAYER_RADIUS, base_color)
        draw_circle(player["pos"], PLAYER_RADIUS + 3.0, Color(0.13, 0.14, 0.18, 0.2), false, 2.0)
        if player["shield_timer"] > 0.0:
            draw_circle(player["pos"], PLAYER_RADIUS + 10.0, Color(0.34, 0.74, 1.0, 0.25), false, 2.0)

    if current_state == "menu":
        draw_rect(Rect2(420.0, 90.0, 440.0, 70.0), Color(0.14, 0.18, 0.34, 0.15), false, 2.0)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and current_state == "playing":
        show_main_menu()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        get_tree().quit()

