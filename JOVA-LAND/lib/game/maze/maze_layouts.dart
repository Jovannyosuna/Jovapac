/// Maze blueprints. Legend:
///   `#` wall · `.` pellet · `o` power burger · ` ` empty floor
///   `t` tunnel floor (slows ghosts) · `-` ghost-house door · `H` ghost house
///   `P` player start
///
/// Every layout keeps the ghost house in rows 6-8 so the shared ghost logic
/// (slots, exit and return paths) works on all of them.
class MazeLayout {
  const MazeLayout(this.name, this.rows);

  final String name;
  final List<String> rows;
}

const MazeLayout classicLayout = MazeLayout('Clásico', [
  '###################',
  '#o.......#.......o#',
  '#.##.###.#.###.##.#',
  '#.................#',
  '#.##.#.#####.#.##.#',
  '#....#.......#....#',
  '####.###---###.####',
  'tt...#HHHHHHH#...tt',
  '####.#HHHHHHH#.####',
  '####.#########.####',
  '#........#........#',
  '#.##.###.#.###.##.#',
  '#o##...........##o#',
  '#.##.#.#####.#.##.#',
  '#....#...P...#....#',
  '###################',
]);

const MazeLayout crossLayout = MazeLayout('Cruce', [
  '###################',
  '#o...#.......#...o#',
  '#.##.#.#####.#.##.#',
  '#.#.............#.#',
  '#.#.##.#####.##.#.#',
  '#....#.......#....#',
  '####.###---###.####',
  'tt...#HHHHHHH#...tt',
  '####.#HHHHHHH#.####',
  '####.#########.####',
  '#.....#.....#.....#',
  '#.###.#.###.#.###.#',
  '#o...............o#',
  '#.##.#.#####.#.##.#',
  '#....#...P...#....#',
  '###################',
]);

const MazeLayout labyrinthLayout = MazeLayout('Laberinto', [
  '###################',
  '#o..#.........#..o#',
  '#.#.#.#.###.#.#.#.#',
  '#.................#',
  '#.##.#.#####.#.##.#',
  '#....#.......#....#',
  '####.###---###.####',
  'tt...#HHHHHHH#...tt',
  '####.#HHHHHHH#.####',
  '####.#########.####',
  '#........#........#',
  '#.##.###.#.###.##.#',
  '#o....##...##....o#',
  '#.#.#.###.###.#.#.#',
  '#........P........#',
  '###################',
]);
