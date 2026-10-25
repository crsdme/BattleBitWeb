# TypeScript и GDScript рядом

Оба языка типизированные. Файл читается сверху вниз, тип пишется у значения, функция объявляет, что принимает и что возвращает.

Дальше расходятся роли файла. В TypeScript файл — модуль: он экспортирует функции и классы, кто-то их импортирует. В Godot файл `.gd` — поведение одной ноды. Движок сам создаёт эту ноду из сцены и сам вызывает `_ready` и `_physics_process`. Импортировать контроллер в карту не нужно: карта держит экземпляр `player.tscn`, а сцена уже ссылается на скрипт.

Имена в этом проекте следуют стилю Godot: функции и переменные `snake_case`, константы `CAPS_SNAKE`, классы и ноды `PascalCase`. Сигнал называют фактом в прошедшем времени: `landed`, `animation_finished`.

## Файл, класс, импорт

TypeScript:

```ts
import { AnimationPlayer } from "./animation-player"

export class PlayerController {
  speed = 4.8
}
```

GDScript, `player_controller.gd`:

```gdscript
extends CharacterBody3D

const SPEED := 4.8
```

| TypeScript | GDScript | Смысл |
| --- | --- | --- |
| `import { X } from "./x"` | `preload("res://scripts/player/fps_arm_ik.gd")` | взять другой скрипт явно |
| `export class Foo` | `class_name Foo` в начале файла | имя видно всему проекту без импорта |
| `class Foo extends Bar` | `extends CharacterBody3D` | один родитель |
| `implements Damageable` | отдельного слова нет | роль задают методом (`take_damage`) или группой нод |
| поле `this.speed` | голое `velocity` | `self` можно не писать |
| `constructor(speed: number)` | `func _init(speed: float = 4.8) -> void` | конструктор |

`class_name PlayerController` делает то же, что глобальный экспорт: в любом файле можно написать `var player: PlayerController`. Пока скрипт сидит только на своей ноде, `class_name` не обязателен. В BBGodot его нет ни у одного скрипта.

`preload` выполняется при компиляции, путь битый — ошибка сразу. Так `view_model.gd` берёт IK:

```gdscript
_ik = preload("res://scripts/player/fps_arm_ik.gd").new()
add_child(_ik)
```

Рядом на TypeScript это `new ArmIk()` после импорта. В Godot объект ещё не в дереве, пока нет `add_child`. До этого `_process` у него не идёт.

У ноды, которую собирает редактор, `_init` не должен требовать аргументов. Сцена создаёт скрипт без параметров. Обязательный конструктор, привычный в TS, сломает такую ноду. Настройки ноды приходят через `@export` и детей, а не через конструктор.

## Переменные

```ts
const SPEED = 4.8
let inAir = false
```

```gdscript
const SPEED := 4.8
var _in_air := false
```

`const` в двух языках — разные обещания.

- В TypeScript `const` значит «эту привязку нельзя переназначить». Значение спокойно считается в рантайме: `const gravity = settings.get("gravity")`.
- В GDScript `const` — константа на этапе компиляции. Туда встаёт число, строка, массив литералов. Вызов `ProjectSettings.get_setting(...)` в `const` не кладут. Поэтому гравитация в контроллере — обычный `var` внутри `_physics_process`.

Слова `let` нет. Изменяемое значение — всегда `var`.

`:=` просит вывести тип из правой части. `4.8` становится `float`, `false` становится `bool`, `"idle"` становится `String`. Это близко к `let x = 4.8`, где TypeScript тоже выводит `number`, только в Godot целое и дробное — разные типы: `int` и `float`.

Явная запись, когда вывод не спасает:

```gdscript
@onready var head: Node3D = $Head
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
```

```ts
let head: Node3D
let gravity: number = settings.get("physics/3d/default_gravity")
```

Подчёркивание в `_in_air` и `_play_body` — договорённость, не запрет компилятора. Из другого скрипта `_play_body` всё равно вызвать можно. Настоящего `private` в GDScript нет. Публичный метод оставляют без подчёркивания: `start_reload`, `update_view`, `is_reloading`.

## Аннотации и декораторы

```ts
@Export()
runSpeedThreshold = 6.5
```

В GDScript то же пишется встроенными аннотациями, они уже есть в языке:

```gdscript
@export var run_speed_threshold := 6.5
@onready var head: Node3D = $Head
```

| Аннотация | Когда срабатывает | Аналог, о котором думать |
| --- | --- | --- |
| `@export` | поле видно в инспекторе ноды | props компонента |
| `@onready` | присвоить прямо перед `_ready` | ref, который заполняют на mount |
| `@tool` | скрипт исполняется и в редакторе | код, который живёт не только в браузере |

`@export` стоит на том, что крутят у конкретной ноды. В `view_model.gd` это масштаб рук и сдвиг винтовки. `const` стоит на законе, общем для всех: `SPEED`, длительности фаз перезарядки.

## Функции

```ts
function updateView(horizontalSpeed: number, onFloor: boolean, verticalSpeed: number): void {
  // ...
}

function isReloading(): boolean {
  return this.reloading
}
```

```gdscript
func update_view(horizontal_speed: float, on_floor: bool, vertical_speed: float) -> void:
    pass

func is_reloading() -> bool:
    return _reloading
```

`-> void` значит «ничего полезного не возвращает». Тип аргумента пишется после имени, как в TS, стрелка возврата тоже похожа: `-> bool` вместо `: boolean`.

Тело с отступами, как в Python. Таб — один уровень. Фигурных скобок вокруг функции нет. Пустое тело, которое ещё не написал, заполняют словом `pass`. В TS на этом месте пустые `{}`.

Значение по умолчанию есть в обоих:

```ts
function play(clip: string, blend = 0.12): void {}
```

```gdscript
func play(clip_name: String, blend: float = 0.12) -> void:
    pass
```

Лямбда в Godot 4 есть и нужна почти только чтобы подписаться на сигнал на месте:

```gdscript
button.pressed.connect(func() -> void:
    print("pressed")
)
```

```ts
button.addEventListener("pressed", () => {
  console.log("pressed")
})
```

Отдельной стрелочной функции на каждое выражение, как `const double = (x: number) => x * 2`, в игровом коде Godot почти не пишут. Обычная `func` читается в сцене лучше.

## Условия, циклы, match

```ts
if (!wasOnFloor) {
  velocity.y -= gravity * delta
} else if (Input.isActionJustPressed("jump")) {
  velocity.y = JUMP_VELOCITY
}
```

```gdscript
if not was_on_floor:
    velocity.y -= gravity * delta
elif Input.is_action_just_pressed("jump"):
    velocity.y = JUMP_VELOCITY
```

`and`, `or`, `not` — основной стиль проекта. Знаки `&&`, `||`, `!` тоже работают. Скобки вокруг условия не нужны.

Тернарный оператор перевёрнут относительно TS:

```ts
const clip = onFloor ? "idle" : "fall"
```

```gdscript
var clip := "idle" if on_floor else "fall"
```

`switch` заменён на `match`. Проваливающихся `case` нет: сработала одна ветка, остальные не исполняются.

```ts
switch (grip) {
  case LeftGrip.Magazine:
    return "MagazineGrip"
  default:
    return "LeftHandGrip"
}
```

```gdscript
match left_grip:
    LeftGrip.MAGAZINE:
        return "MagazineGrip"
    _:
        return "LeftHandGrip"
```

Цикл по массиву:

```ts
for (const clipName of looping) {
  if (player.hasAnimation(clipName)) {
    player.getAnimation(clipName).loopMode = LoopLinear
  }
}
```

```gdscript
for clip_name in looping:
    if animation_player.has_animation(clip_name):
        animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
```

Индекс:

```ts
for (let i = 0; i < vertices.length; i++) {}
```

```gdscript
for vertex_idx in vertices.size():
    pass
```

`range(0, indices.size() - 2, 3)` — начало, конец не включая, шаг. Так `body_local_visibility.gd` идёт по треугольникам.

## Типы, null, приведение

| TypeScript | GDScript |
| --- | --- |
| `number` | `int` или `float`. Дробь — всегда `float` |
| `string` | `String` |
| `boolean` | `bool` |
| `string[]` | `Array[String]` |
| `Record<string, number>` | `Dictionary` |
| `T \| null` | значение этого типа или `null` |
| `unknown` / `any` | `Variant` |
| литерал `"idle" \| "walk"` | обычный `String`, договорённость в константах |

Массив с типом элемента:

```gdscript
var _chains: Array[Dictionary] = []
const _HEAD_BONES: PackedStringArray = ["Head", "Neck"]
```

`PackedStringArray`, `PackedVector3Array`, `PackedInt32Array` — плотные массивы без лишних аллокаций. Их используют там, где лежат вершины меша, как в `body_local_visibility.gd`. Обычный `Array` удобнее для коротких списков клипов.

Словарь — это объект TS, у которого ключи часто строки:

```ts
const chain = {
  root: skeleton.findBone(rootBone),
  target,
}
const root = chain.root
```

```gdscript
_chains.append({
    "root": skeleton.find_bone(root_bone),
    "target": target,
})
var root: int = chain["root"]
```

Приведение `as` в GDScript проверяется в рантайме. Не совпал тип — получишь `null`, а не исключение и не тихую ложь.

```ts
const mesh = node as MeshInstance3D
```

```gdscript
var mesh_instance := node as MeshInstance3D
```

Проверка типа — слово `is`. Это `instanceof`:

```ts
if (event instanceof InputEventMouseMotion) {}
```

```gdscript
if event is InputEventMouseMotion:
    rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
```

Оператор `?.` и `??` в GDScript нет. Проверку пишут явно, как в IK:

```gdscript
if root < 0 or middle < 0 or end < 0 or target == null or pole == null:
    return
```

Пустая строка, пустой массив и пустой словарь в условии считаются истиной. Ложь — это `false`, `null`, `0` и `0.0`. Привычка из JS «пустая строка значит нет клипа» здесь не сработает: проверяют `clip_name == ""`, как делает `_hands_oneshot != ""` в анимации.

`==` сравнивает значение. Отдельного `===` нет. Для объектов `==` — это тот же экземпляр.

## Enum

Одинаковая идея. В GDScript члены — целые, доступ через имя типа.

```ts
enum LeftGrip {
  Handguard,
  Magazine,
}
```

```gdscript
enum LeftGrip { HANDGUARD, MAGAZINE }

@export var left_grip: LeftGrip = LeftGrip.HANDGUARD
```

`@export` на enum даёт выпадающий список в инспекторе. Это уже используется у `ViewModel`.

## Строки

Шаблона `` `speed ${speed}` `` нет.

```gdscript
print("speed ", horizontal_speed)
push_error("FPS IK is missing the hand skeleton, a grip marker, or the magazine.")
```

Сборка через `%`:

```gdscript
var message := "clip %s missing" % clip_name
```

Несколько кусков — массив после `%`:

```gdscript
var message := "%s -> %s" % [from_clip, to_clip]
```

Комментарий для себя — `#`. Документация, которую редактор показывает в подсказке, — `##` над скриптом или функцией. В TS на этом месте `/** ... */`.

## Ссылки на ноды вместо querySelector

```ts
const head = this.querySelector(":scope > Head") as Node3D
const view = this.parent.querySelector("Head/Camera3D/ViewModel")
```

```gdscript
@onready var head: Node3D = $Head
@onready var _view: Node3D = $"../Head/Camera3D/ViewModel"
```

`$Head` — прямой ребёнок. `$Head/Camera3D/ViewModel` — путь вниз. `..` — родитель. Кавычки нужны, когда в пути есть слэш. Уникальное имя в сцене пишется `%Animation` и не зависит от глубины.

`@onready` обязателен для `$`. В момент `_init` детей в дереве ещё нет, путь вернёт пустоту. Присвоение происходит сразу перед `_ready`, когда сцена уже собрана.

Поиск внутри glb, где промежуточные ноды может переименовать повторный экспорт:

```gdscript
_skeleton = hands.find_child("Skeleton3D", true, false) as Skeleton3D
```

Это ближе к `element.querySelector('[name="Skeleton3D"]')`, чем к жёсткому пути.

## Сигналы и колбэки

```ts
animationPlayer.addEventListener("finished", (animName: string) => {
  this.onBodyFinished(animName)
})
```

```gdscript
animation_player.animation_finished.connect(finished)
```

Свой сигнал:

```ts
class Player extends EventTarget {
  jump(): void {
    this.dispatchEvent(new Event("jumped"))
  }
}
player.addEventListener("jumped", () => animation.notifyJumped())
```

```gdscript
signal jumped

func _physics_process(delta: float) -> void:
    if _in_air and is_on_floor():
        jumped.emit()
```

Подписка жива, пока её не снимут или нода не умрёт. Снятие — `disconnect`. В BBGodot свои сигналы не объявлены: контроллер зовёт `animation.notify_landed()` напрямую. Чужой сигнал движка уже используется: `animation_finished.connect(...)`.

`await` ждёт сигнал, а не Promise:

```ts
await new Promise((resolve) => setTimeout(resolve, 1000))
await new Promise<void>((resolve) => player.addEventListener("landed", () => resolve(), { once: true }))
```

```gdscript
await get_tree().create_timer(1.0).timeout
await jumped
```

Пока функция стоит на `await`, остальной кадр игры идёт дальше. Это кооперативное ожидание на сигналах, не отдельный поток и не `async/await` поверх Promise. Слово `async` писать не нужно: любая функция может сделать `await`.

## Ошибки

`try / catch` в GDScript нет. Ветку «не получилось» делают возвратом и проверкой `null`.

```ts
throw new Error("missing AnimationPlayer")
```

```gdscript
push_error("A player model is missing its AnimationPlayer.")
return
```

`push_error` пишет красную строку в Output, игра продолжает кадр. Так сделаны и IK, и анимация: нет скелета — выходим, а не валим процесс. `assert(condition)` остаётся для проверки, которая обязана быть истинной в отладке.

`start_reload() -> bool` — тот же приём, что `function startReload(): boolean`. `false` значит «уже идёт или IK не собрался».

## Геттеры

```ts
private magazine = 30

get ammo(): number {
  return this.magazine
}

set ammo(value: number) {
  this.magazine = Math.max(0, Math.min(30, value))
}
```

```gdscript
var magazine := 30:
    get:
        return magazine
    set(value):
        magazine = clampi(value, 0, 30)
```

В текущих скриптах своих геттеров нет. Состояние отдают обычной функцией `is_reloading()`.

## Кусок контроллера целиком

Так этот кадр выглядел бы классом TypeScript, если бы движок сам вызывал `physicsProcess`:

```ts
const SPEED = 4.8
const ACCELERATION = 28
const JUMP_VELOCITY = 4.6

class PlayerController {
  velocity = { x: 0, y: 0, z: 0 }
  inAir = false

  physicsProcess(delta: number): void {
    const wasOnFloor = this.isOnFloor()
    const gravity = 9.8
    if (!wasOnFloor) {
      this.velocity.y -= gravity * delta
    } else if (Input.isActionJustPressed("jump")) {
      this.velocity.y = JUMP_VELOCITY
      this.animation.notifyJumped()
    }

    const inputDir = Input.getVector("move_left", "move_right", "move_forward", "move_back")
    const direction = this.basis.times(inputDir.x, 0, inputDir.y).normalized()
    const target = direction.times(SPEED)
    this.velocity.x = moveToward(this.velocity.x, target.x, ACCELERATION * delta)
    this.velocity.z = moveToward(this.velocity.z, target.z, ACCELERATION * delta)
    this.moveAndSlide()

    if (wasOnFloor && !this.isOnFloor()) this.inAir = true
    if (this.inAir && this.isOnFloor()) {
      this.animation.notifyLanded()
      this.inAir = false
    }
  }
}
```

Тот же кадр в `player_controller.gd`:

```gdscript
func _physics_process(delta: float) -> void:
    var was_on_floor := is_on_floor()
    var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
    if not was_on_floor:
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_VELOCITY
        animation.notify_jumped()

    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
    var target := direction * SPEED
    velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
    velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)
    move_and_slide()

    if was_on_floor and not is_on_floor():
        _in_air = true
    if _in_air and is_on_floor():
        animation.notify_landed()
        _in_air = false
```

Подчёркивание у `_physics_process` здесь значит другое, чем у `_in_air`. Имена `_ready`, `_process`, `_physics_process`, `_unhandled_input`, `_init`, `_enter_tree`, `_exit_tree` зарезервированы движком: он их вызывает сам. Своё внутреннее имя тоже начинают с `_`, но движок такие функции не ищет.

## Памятка перевода

| Пишешь в TypeScript | Пишешь в этом проекте |
| --- | --- |
| `let speed = 4.8` | `var speed := 4.8` |
| `const SPEED = 4.8` на уровне модуля | `const SPEED := 4.8` |
| `foo: string` | `foo: String` |
| `foo?: Node` | `var foo: Node = null` и проверка `if foo == null` |
| `obj?.x` | `if obj != null: obj.x` |
| `a ? b : c` | `b if a else c` |
| `for (const x of list)` | `for x in list:` |
| `list.length` | `list.size()` |
| `console.log(x)` | `print(x)` |
| `instanceof` | `is` |
| `as` без проверки в рантайме | `as` с `null`, если тип не совпал |
| `addEventListener` / `emit` | `signal` и `connect` / `emit` |
| `await promise` | `await signal` |
| `querySelector` | `$Path`, `%Unique`, `find_child` |
| `props` | `@export` |
| `ref` после mount | `@onready var n := $Child` |
| `private method` | `func _method` по договорённости |
| `export class` | `class_name` |
| `requestAnimationFrame` | `_process(delta)` |
| фиксированный шаг физики | `_physics_process(delta)` |
| `element.remove()` | `queue_free()` |

Дальше по порядку чтения — полный жизненный цикл ноды в `04b_жизненный_цикл_полностью.md`. Глава `04_жизненный_цикл.md` остаётся разбором конкретных функций игрока.
