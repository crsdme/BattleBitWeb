# GDScript с нуля, на этом проекте

GDScript похож на Python по отступам и на статически типизированный язык по аннотациям. Отступ — таб. Тип пишется после двоеточия.

Файл — это скрипт одной ноды. Он начинается со строки `extends`.

## extends

```gdscript
extends CharacterBody3D
```

«Этот скрипт добавляет поведение ноде такого типа». После этой строки `velocity`, `global_position`, `rotate_y` — уже твои, они пришли от класса ноды.

Соответствие в проекте:

| Файл | extends | Почему этот тип |
| --- | --- | --- |
| `player_controller.gd` | `CharacterBody3D` | нужны физика и `move_and_slide` |
| `player_animation.gd` | `Node` | только выбирает клипы, позиции нет |
| `view_model.gd` | `Node3D` | двигает оружие и руки в пространстве |
| `fps_arm_ik.gd` | `Node` | считает кости, сам в мире не стоит |
| `body_local_visibility.gd` | `Node` | висит на `Body`, но сам тип ноды в сцене `Node3D`. Скрипт просит только методы `Node`, этого хватает |

Скрипт с `extends Node` можно повесить на `Node3D`, потому что `Node3D` является `Node`. Наоборот нельзя: скрипту `CharacterBody3D` не хватит обычного `Node3D`.

## Комментарии

```gdscript
## Full-body clips live on the imported soldier AnimationPlayer.
```

`##` в начале файла или над функцией — документация. Godot показывает её во всплывающей подсказке. Обычный комментарий для себя — одна решётка `#`.

## const, var, @export

```gdscript
const SPEED := 4.8
@export var run_speed_threshold := 6.5
var _in_air := false
```

- `const` — значение известно до запуска и не меняется. Скорость ходьбы, имена клипов, длительности фаз перезарядки.
- `var` — память скрипта, живёт пока жива нода.
- `@export` — то же `var`, но поле видно в инспекторе. Меняешь число у конкретной ноды, файл скрипта не трогаешь.
- `:=` велит Godot вывести тип из значения. `4.8` становится `float`, `false` становится `bool`.
- Подчёркивание в начале имени (`_in_air`, `_play_body`) — договорённость: это внутреннее. Снаружи скрипта так не вызывают.

Тип можно написать явно:

```gdscript
var _body_clip := ""          # Godot поймёт String
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var head: Node3D = $Head
```

Явный тип ловит ошибку раньше. Если в `head` случайно попадёт `AnimationPlayer`, редактор подсветит это до запуска.

## @onready и доллар

```gdscript
@onready var head: Node3D = $Head
@onready var animation: Node = $Animation
@onready var view_model: Node3D = $Head/Camera3D/ViewModel
```

`$Head` значит «дочерняя нода с именем Head». Путь считается от ноды, на которой висит скрипт. Из корня `Player` путь `$Head/Camera3D/ViewModel` ведёт к вьюмодели.

`@onready` откладывает этот поиск до момента, когда нода уже вставлена в дерево. До этого детей ещё нет, и `$Head` вернул бы `null`.

Из `player_animation.gd` путь начинается с `..`, потому что скрипт висит не на корне, а на дочерней ноде `Animation`:

```gdscript
@onready var _view: Node3D = $"../Head/Camera3D/ViewModel"
```

Кавычки нужны, когда в пути есть точки и слэши. `$Head` без кавычек работает для одного простого имени.

## func

```gdscript
func _ready() -> void:
    _ensure_actions()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_reloading() -> bool:
    return _reloading
```

`-> void` — функция ничего не возвращает. `-> bool` — возвращает да или нет. `-> String` — возвращает строку.

Аргументы тоже типизируют:

```gdscript
func update_view(horizontal_speed: float, on_floor: bool, vertical_speed: float) -> void:
```

Вызов из контроллера:

```gdscript
animation.update_view(horizontal_speed, animate_grounded, velocity.y)
```

Контроллер не выбирает клип. Он сообщает три числа. Выбор клипа живёт в `player_animation.gd`. Так скрипты остаются короткими.

Имена с подчёркиванием вызывают только из того же файла:

```gdscript
func _bind_key(action: String, keycode: Key) -> void:
```

Имена без подчёркивания — наружный интерфейс ноды: `notify_jumped()`, `start_reload()`, `update_view()`, `is_reloading()`.

## if, and, not

```gdscript
if not was_on_floor:
    velocity.y -= gravity * delta
elif Input.is_action_just_pressed("jump"):
    velocity.y = JUMP_VELOCITY
```

Условия без скобок. `and`, `or`, `not` — слова, не символы `&&`.

`elif` — следующая ветка. В этом примере прыжок проверяется только когда персонаж на полу, потому что ветка `if not was_on_floor` забрала все кадры в воздухе.

## Цикл и массив

```gdscript
const LOOPING_BODY := ["idle", "walk", "run", "sprint", "crouch", "fall"]

for clip_name in looping:
    if animation_player.has_animation(clip_name):
        animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
```

Массив в квадратных скобках. `for x in массив` проходит по элементам. Здесь скрипт не создаёт анимации: он находит уже импортированные и включает им линейный цикл. Если клипа с таким именем в glb нет, строка тихо пропускается.

## enum

```gdscript
enum LeftGrip { HANDGUARD, MAGAZINE }
@export var left_grip: LeftGrip = LeftGrip.HANDGUARD
```

Перечисление — это набор имён вместо голых чисел. В инспекторе у `ViewModel` появляется выпадающий список. Код сравнивает `left_grip == LeftGrip.MAGAZINE`, а не `left_grip == 1`.

## Словарь

В `fps_arm_ik.gd` цепь руки хранится так:

```gdscript
_chains.append({
    "root": skeleton.find_bone(root_bone),
    "middle": skeleton.find_bone(middle_bone),
    "end": skeleton.find_bone(end_bone),
    "target": target,
    "pole": pole,
})
```

Словарь — пары «имя → значение». Достают так: `chain["root"]`. Для двух рук массив словарей проще, чем заводить отдельный класс. Когда полей станет больше и ими начнут пользоваться три системы, словарь заменяют своим `class_name` с полями. Пока IK один, словаря достаточно.

## Сигнал

```gdscript
animation_player.animation_finished.connect(finished)
```

`animation_finished` — сигнал `AnimationPlayer`. Он стреляет, когда клип доиграл. `.connect(finished)` подписывает функцию. Для тела это `_on_body_finished`, для рук — `_on_hands_finished`.

Свой сигнал объявляют так:

```gdscript
signal landed

func _physics_process(delta: float) -> void:
    if _in_air and is_on_floor():
        landed.emit()
```

В текущем проекте свои сигналы не объявлены. Контроллер вызывает методы напрямую: `animation.notify_landed()`. Для пяти скриптов одного игрока это читается проще. Сигналы становятся нужны, когда слушателей много и они не должны знать друг о друге. Об этом глава `06_большие_системы.md`.

## preload и создание ноды из кода

```gdscript
_ik = preload("res://scripts/player/fps_arm_ik.gd").new()
_ik.name = "ArmIK"
_ik.skeleton = _skeleton
add_child(_ik)
```

`preload` загружает скрипт на этапе компиляции. `.new()` делает объект, которого ещё нет в дереве. `add_child` вставляет его. Пока `add_child` не вызван, у объекта не работают `_ready` и `_process`.

Поля без `@onready` можно задать до вставки в дерево. Здесь `skeleton` записывается до `add_child`, и `_process` IK уже видит скелет.

Тот же приём создаёт маркеры:

```gdscript
var pole := Marker3D.new()
pole.name = pole_name
pole.position = position
add_child(pole)
```

Маркер не нарисован в `.tscn`, потому что он служебный: его позиция — деталь алгоритма, а не уровень.

## Поиск ноды по имени внутри модели

```gdscript
_skeleton = hands.find_child("Skeleton3D", true, false) as Skeleton3D
var right_grip := weapon.find_child("RightHandGrip", true, false) as Node3D
```

`find_child` ищет по всему поддереву. Импортированный glb имеет свою вложенность, и точный путь `$Weapon/Skeleton3D/RightHandGrip` ломается при повторном экспорте из Blender. Поиск по имени переживает лишнюю промежуточную ноду.

`as Skeleton3D` приводит результат к типу. Если имя не найдено, получится `null`. Дальше скрипт проверяет все находки разом и пишет `push_error(...)`, если чего-то нет. Игра не падает молча с непонятным `null` на следующей строке.

Имена, которые Blender обязан сохранить в `M4A1_with_grips.glb`:

- `RightHandGrip`
- `LeftHandGrip`
- `MagazineGrip`
- `Magazine`

Имена костей рук:

- `ArmsRoot`
- `UpperArm.R`, `Forearm.R`, `Hand.R`
- `UpperArm.L`, `Forearm.L`, `Hand.L`

Это контракт между моделью и кодом. Его держат в комментарии скрипта и в имени файла модели.

## Vector3, Basis, Transform3D

Позиция — `Vector3(x, y, z)`. В Godot Y вверх, X вправо, Z на зрителя в стандартной камере (минус Z — вперёд взгляда).

```gdscript
var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
```

`transform.basis` — поворот ноды, три оси. Умножение вектора на basis переводит «вправо/вперёд относительно тела» в мировые координаты. `normalized()` делает длину вектора равной 1, чтобы шаг по диагонали не был быстрее шага вперёд.

`Transform3D` — поворот плюс позиция. У винтовки его собирают так:

```gdscript
var weapon_basis := Basis(Vector3.UP, deg_to_rad(weapon_yaw_degrees)).scaled(Vector3.ONE * weapon_scale)
weapon.transform = Transform3D(weapon_basis, weapon_offset)
```

`Basis(ось, угол)` — поворот вокруг оси. `deg_to_rad` нужен, потому что движок считает углы в радианах, а человеку удобнее градусы в `@export`.

## Класс Input

```gdscript
Input.get_vector("move_left", "move_right", "move_forward", "move_back")
Input.is_action_just_pressed("jump")
Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

Код не спрашивает «нажата ли клавиша W». Он спрашивает действие `move_forward`. Какая физическая клавиша к нему привязана, решает Input Map. Сейчас привязку делает `_bind_key`. Позже её можно перенести в настройки проекта, и эти три строки останутся теми же.

`is_action_just_pressed` истинен один кадр, в момент нажатия. `is_action_pressed` истинен всё время, пока кнопка удерживается. Прыжок и перезарядка — `just_pressed`. Движение — вектор, он сам читает удержание.

## Короткий словарь синтаксиса

| Запись | Смысл |
| --- | --- |
| `extends Type` | скрипт на ноде этого типа |
| `const X := 1` | постоянное |
| `var x := 0` | переменная |
| `@export var x := 1.0` | переменная в инспекторе |
| `@onready var n := $Child` | найти ноду после входа в дерево |
| `func f(a: float) -> void` | функция |
| `$Name` или `%"UniqueName"` | путь к ноде |
| `signal exploded` | событие, на которое подписываются |
| `preload("res://...").new()` | создать объект из скрипта |
| `add_child(node)` | вставить объект в дерево |
| `node as Type` | привести тип, иначе `null` |
| `push_error("...")` | красная ошибка в Output, игра жива |
