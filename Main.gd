extends Node2D

const ARENA := Rect2(40.0, 60.0, 1200.0, 600.0)
const PLAYER_RADIUS := 18.0
const BOMB_RADIUS := 14.0
const PICKUP_RADIUS := 12.0
const MAX_BOMBS := 20
const STARTING_BOMBS := 8
const BOMB_SPAWN_INTERVAL := 0.6
const PICKUP_SPAWN_INTERVAL := 5.0

const COLORS := {
    "Red": Color(1.0, 0.34, 0.38),
    "Orange": Color(1.0, 0.57, 0.18),
    "Yellow": Color(1.0, 0.82, 0.22),
    "Green": Color(0.26, 0.76, 0.38),
    "Blue": Color(0.22, 0.52, 1.0),
    "Indigo": Color(0.42, 0.34, 0.86),
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

var players: Array = []
var bombs: Array = []
var pickups: Array = []

var bomb_spawn_timer := 0.0
var pickup_spawn_timer := 0.0
var current_state := "menu"
var total_time := 0.0
var final_text := ""

func _ready() -> void:
    randomize()
    build_ui()
    show_main_menu()

func build_ui() -> void:
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

func clear_screen(screen: Control) -> void:
    for child in screen.get_children():
        child.queue_free()

func make_label(parent: Control, text: String, size: int, color: Color, x: float, y: float) -> Label:
    var label := Label.new()
    label.text = text
    label.position = Vector2(x, y)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func make_button(parent: Control, text: String, x: float, y: float, w: float = 220.0, h: float = 54.0) -> Button:
    var button := Button.new()
    button.text = text
    button.position = Vector2(x, y)
    button.custom_minimum_size = Vector2(w, h)
    button.focus_mode = Control.FOCUS_NONE
    parent.add_child(button)
    return button

func show_main_menu() -> void:
    current_state = "menu"
    for screen in [menu_screen, color_screen, hud_screen, result_screen]:
        screen.visible = false
    menu_screen.visible = true
    clear_screen(menu_screen)

    var title := make_label(menu_screen, "BOMB DODGE", 54, Color(0.9, 0.94, 1.0), 440.0, 110.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(400.0, 60.0)

    var solo_button := make_button(menu_screen, "Solo", 540.0, 280.0)
    solo_button.pressed.connect(func() -> void:
        mode = "solo"
        show_color_screen()
    )

    var multi_button := make_button(menu_screen, "Local Multiplayer", 500.0, 360.0, 280.0, 54.0)
    multi_button.pressed.connect(func() -> void:
        mode = "local"
        show_color_screen()
    )

    var exit_button := make_button(menu_screen, "Exit", 540.0, 440.0)
    exit_button.pressed.connect(func() -> void:
        get_tree().quit()
    )

func show_color_screen() -> void:
    current_state = "color_select"
    for screen in [menu_screen, color_screen, hud_screen, result_screen]:
        screen.visible = false
    color_screen.visible = true
    clear_screen(color_screen)

    ensure_unique_colors()

    var title := make_label(color_screen, "Choose Colors", 40, Color(0.92, 0.96, 1.0), 480.0, 60.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(320.0, 50.0)

    if mode == "solo":
        var panel := build_color_panel(color_screen, "Solo Player", 0)
        panel.position = Vector2(420.0, 160.0)

        var start_button := make_button(color_screen, "Start", 540.0, 560.0, 200.0, 54.0)
        start_button.pressed.connect(start_game)
    else:
        var p1_panel := build_color_panel(color_screen, "Player 1", 0)
        p1_panel.position = Vector2(260.0, 180.0)

        var p2_panel := build_color_panel(color_screen, "Player 2", 1)
        p2_panel.position = Vector2(760.0, 180.0)

        var start_button := make_button(color_screen, "Start", 540.0, 560.0, 200.0, 54.0)
        start_button.pressed.connect(start_game)

func build_color_panel(parent: Control, label_text: String, slot: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(220.0, 160.0)
    parent.add_child(panel)

    var vbox := VBoxContainer.new()
    panel.add_child(vbox)

    var title := make_label(vbox, label_text, 22, Color(0.95, 0.98, 1.0), 0.0, 0.0)
    title.custom_minimum_size = Vector2(220.0, 32.0)

    var current_color := solo_color
    if mode == "local":
        current_color = p1_color if slot == 0 else p2_color

    var status := make_label(vbox, "Selected: " + current_color, 18, Color(0.8, 0.9, 1.0), 0.0, 0.0)

    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(row)

    for color_name in COLOR_NAMES:
        var button := make_button(row, color_name, 0.0, 0.0, 80.0, 40.0)
        button.modulate = COLORS[color_name]
        button.disabled = is_color_taken_by_other(color_name, slot)
        button.pressed.connect(func() -> void:
            set_player_color(slot, color_name)
        )

    return panel

func is_color_taken_by_other(color_name: String, slot: int) -> bool:
    if mode == "solo":
        return false
    if slot == 0:
        return color_name == p2_color
    return color_name == p1_color

func set_player_color(slot: int, color_name: String) -> void:
    if mode == "solo":
        solo_color = color_name
    elif slot == 0:
        p1_color = color_name
    else:
        p2_color = color_name

    ensure_unique_colors()
    if current_state == "color_select":
        show_color_screen()

func ensure_unique_colors() -> void:
    if mode == "local" and p1_color == p2_color:
        p2_color = next_available_color(p1_color)

func next_available_color(excluded: String) -> String:
    for color_name in COLOR_NAMES:
        if color_name != excluded:
            return color_name
    return excluded

func start_game() -> void:
    current_state = "playing"
    players.clear()
    bombs.clear()
    pickups.clear()
    bomb_spawn_timer = 0.0
    pickup_spawn_timer = 0.0
    total_time = 0.0
    final_text = ""

    clear_screen(hud_screen)
    for screen in [menu_screen, color_screen, result_screen]:
        screen.visible = false
    hud_screen.visible = true

    if mode == "solo":
        players.append(create_player("P1", solo_color, Vector2(150.0, 360.0)))
    else:
        players.append(create_player("P1", p1_color, Vector2(180.0, 250.0)))
        players.append(create_player("P2", p2_color, Vector2(180.0, 470.0)))

    for i in range(STARTING_BOMBS):
        spawn_bomb()

    create_hud()

func create_player(name: String, color_name: String, position: Vector2) -> Dictionary:
    return {
        "name": name,
        "color": color_name,
        "position": position,
        "speed": 310.0,
        "move_dir": Vector2.RIGHT,
        "dash_timer": 0.0,
        "dash_direction": Vector2.RIGHT,
        "dash_collected": false,
        "shield_timer": 0.0,
        "shield_collected": false,
        "last_click_ms": 0,
        "dead": false,
        "hud_button": null
    }

func create_hud() -> void:
    var title := make_label(hud_screen, "Survival Time:", 24, Color(0.85, 0.9, 1.0), 515.0, 8.0)
    timer_label = make_label(hud_screen, "00.0s", 28, Color(1.0, 1.0, 1.0), 565.0, 36.0)

    for index in range(players.size()):
        var player := players[index]
        var label_x := 30.0 + index * 320.0
        var name_label := make_label(hud_screen, player["name"], 22, COLORS[player["color"]], label_x, 18.0)

        var button := Button.new()
        button.position = Vector2(label_x, 52.0)
        button.custom_minimum_size = Vector2(70.0, 40.0)
        button.focus_mode = Control.FOCUS_NONE
        button.visible = false
        button.text = ""
        button.pressed.connect(func() -> void:
            activate_ability(player)
        )
        hud_screen.add_child(button)
        player["hud_button"] = button

func activate_ability(player: Dictionary) -> void:
    var now := Time.get_ticks_msec()
    var double_click := now - int(player["last_click_ms"]) < 300
    player["last_click_ms"] = now

    if double_click:
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
    timer_label.text = str(snapped(total_time, 0.1)) + "s"

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

        update_player(player, delta)

        if player["dash_timer"] > 0.0:
            player["dash_timer"] = max(0.0, player["dash_timer"] - delta)

        if player["shield_timer"] > 0.0:
            player["shield_timer"] = max(0.0, player["shield_timer"] - delta)

    for bomb in bombs:
        bomb["countdown"] -= delta
        if bomb["countdown"] <= 0.0:
            detonate_bomb(bomb)

    for pickup in pickups:
        for player in players:
            if player["dead"]:
                continue
            if player["position"].distance_to(pickup["position"]) <= PLAYER_RADIUS + PICKUP_RADIUS:
                if pickup["type"] == "Dash" and player["color"] == "Red":
                    player["dash_collected"] = true
                    pickups.erase(pickup)
                    break
                if pickup["type"] == "Shield" and player["color"] == "Blue":
                    player["shield_collected"] = true
                    pickups.erase(pickup)
                    break

    update_ability_hud()
    check_game_end()
    queue_redraw()

func update_player(player: Dictionary, delta: float) -> void:
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
        player["position"] += player["dash_direction"] * 950.0 * delta
    else:
        player["position"] += move * player["speed"] * delta

    player["position"] = clamp_in_arena(player["position"], PLAYER_RADIUS)

func clamp_in_arena(pos: Vector2, radius: float) -> Vector2:
    var min_x := ARENA.position.x + radius
    var max_x := ARENA.position.x + ARENA.size.x - radius
    var min_y := ARENA.position.y + radius
    var max_y := ARENA.position.y + ARENA.size.y - radius
    return Vector2(clamp(pos.x, min_x, max_x), clamp(pos.y, min_y, max_y))

func spawn_bomb() -> void:
    if bombs.size() >= MAX_BOMBS:
        return

    var pos := find_safe_bomb_position()
    bombs.append({
        "position": pos,
        "countdown": randf_range(2.0, 3.0),
        "radius": BOMB_RADIUS
    })

func find_safe_bomb_position() -> Vector2:
    for attempt in range(200):
        var x := randf_range(ARENA.position.x + 60.0, ARENA.position.x + ARENA.size.x - 60.0)
        var y := randf_range(ARENA.position.y + 60.0, ARENA.position.y + ARENA.size.y - 60.0)
        var candidate := Vector2(x, y)
        var safe := true

        for player in players:
            if candidate.distance_to(player["position"]) < 80.0:
                safe = false
                break

        if safe:
            return candidate

    return Vector2(ARENA.position.x + 120.0, ARENA.position.y + 120.0)

func spawn_pickup() -> void:
    var types: Array = []
    for player in players:
        if player["color"] == "Red":
            types.append("Dash")
        if player["color"] == "Blue":
            types.append("Shield")

    if types.is_empty():
        return

    var type_name := types[randi() % types.size()]
    var pos := Vector2(
        randf_range(ARENA.position.x + 80.0, ARENA.position.x + ARENA.size.x - 80.0),
        randf_range(ARENA.position.y + 80.0, ARENA.position.y + ARENA.size.y - 80.0)
    )

    pickups.append({
        "type": type_name,
        "position": pos,
        "radius": PICKUP_RADIUS,
        "color": Color(1.0, 0.28, 0.28) if type_name == "Dash" else Color(0.2, 0.55, 1.0)
    })

func detonate_bomb(bomb: Dictionary) -> void:
    bombs.erase(bomb)
    for player in players:
        if player["dead"]:
            continue
        if player["shield_timer"] > 0.0:
            continue
        if player["position"].distance_to(bomb["position"]) <= 90.0:
            player["dead"] = true

func check_game_end() -> void:
    var alive: Array = []
    for player in players:
        if not player["dead"]:
            alive.append(player)

    if mode == "solo":
        if alive.is_empty():
            final_text = "You were eliminated!\nFinal Time: " + str(snapped(total_time, 0.1)) + "s"
            show_result_screen()
        elif alive.size() == 1:
            final_text = "You survived!\nFinal Time: " + str(snapped(total_time, 0.1)) + "s"
            show_result_screen()
    else:
        if alive.size() <= 1:
            if alive.size() == 1:
                final_text = alive[0]["name"] + " wins!\nFinal Time: " + str(snapped(total_time, 0.1)) + "s"
            else:
                final_text = "Draw!\nFinal Time: " + str(snapped(total_time, 0.1)) + "s"
            show_result_screen()

func show_result_screen() -> void:
    current_state = "result"
    for screen in [menu_screen, color_screen, hud_screen]:
        screen.visible = false
    result_screen.visible = true
    clear_screen(result_screen)

    var title := make_label(result_screen, "Result", 42, Color(0.95, 0.97, 1.0), 520.0, 120.0)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size = Vector2(240.0, 50.0)

    var result_label := make_label(result_screen, final_text, 28, Color(1.0, 1.0, 1.0), 370.0, 210.0)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.custom_minimum_size = Vector2(540.0, 120.0)

    var restart_button := make_button(result_screen, "Restart", 430.0, 420.0, 180.0, 54.0)
    restart_button.pressed.connect(func() -> void:
        show_color_screen()
    )

    var main_menu_button := make_button(result_screen, "Main Menu", 670.0, 420.0, 180.0, 54.0)
    main_menu_button.pressed.connect(show_main_menu)

func update_ability_hud() -> void:
    for player in players:
        var button: Button = player["hud_button"]
        if button == null:
            continue

        if player["color"] == "Red":
            if player["dash_collected"]:
                button.text = "Dash"
                button.visible = true
                button.modulate = Color(1.0, 0.32, 0.32)
            elif player["dash_timer"] > 0.0:
                button.text = "D!"
                button.visible = true
                button.modulate = Color(1.0, 0.75, 0.75)
            else:
                button.visible = false
        elif player["color"] == "Blue":
            if player["shield_collected"]:
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

func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.03, 0.08, 0.20))
    draw_rect(ARENA, Color(0.08, 0.12, 0.28), false, 3.0)

    for bomb in bombs:
        var color := Color(1.0, 0.62, 0.25)
        if bomb["countdown"] <= 1.0:
            color = Color(1.0, 0.35, 0.15)
        draw_circle(bomb["position"], bomb["radius"], color)
        draw_arc(bomb["position"], bomb["radius"] + 4.0, 0.0, TAU, 12, Color(1.0, 0.85, 0.7, 0.8), 1.5)

    for pickup in pickups:
        draw_circle(pickup["position"], pickup["radius"], pickup["color"])
        draw_arc(pickup["position"], pickup["radius"] + 3.0, 0.0, TAU, 10, Color(1.0, 1.0, 1.0, 0.7), 2.0)

    for player in players:
        if player["dead"]:
            continue

        draw_circle(player["position"], PLAYER_RADIUS, COLORS[player["color"]])
        draw_circle(player["position"], PLAYER_RADIUS + 3.0, Color(0.13, 0.14, 0.18, 0.2), false, 2.0)

        if player["shield_timer"] > 0.0:
            draw_circle(player["position"], PLAYER_RADIUS + 10.0, Color(0.34, 0.74, 1.0, 0.25), false, 2.0)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and current_state == "playing":
        show_main_menu()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        get_tree().quit()
