//=============================================================================
// Pure level-map parsing (CreateJS-free). Used by buildLevelMap and by tests.
//
// parseLevelChar  - tile char → {base, act, kind} (no state)
// resolveLevelMap - full buildLevelMap tile resolution including:
//                   maxGuard culling (first excess '0's demoted) and
//                   first-&-wins runner demotion.
//=============================================================================

// Legal tile characters in shipped / editable level strings.
var LEGAL_LEVEL_CHARS = " #@H-XS$0&";

/**
 * Map one level character to base/act tile types (no sprites).
 * Unknown characters follow the original default → empty path.
 *
 * @returns {{ base: number, act: number, kind: string }}
 */
function parseLevelChar(id)
{
	switch (id) {
	default:
	case ' ': // empty
		return { base: EMPTY_T, act: EMPTY_T, kind: "empty" };
	case '#': // Normal Brick
		return { base: BLOCK_T, act: BLOCK_T, kind: "brick" };
	case '@': // Solid Brick
		return { base: SOLID_T, act: SOLID_T, kind: "solid" };
	case 'H': // Ladder
		return { base: LADDR_T, act: LADDR_T, kind: "ladder" };
	case '-': // Line of rope
		return { base: BAR_T, act: BAR_T, kind: "rope" };
	case 'X': // False brick
		return { base: TRAP_T, act: TRAP_T, kind: "trap" };
	case 'S': // Ladder appears at end of level
		return { base: HLADR_T, act: EMPTY_T, kind: "hladder" };
	case '$': // Gold chest
		return { base: GOLD_T, act: EMPTY_T, kind: "gold" };
	case '0': // Guard
		return { base: EMPTY_T, act: GUARD_T, kind: "guard" };
	case '&': // Player
		return { base: EMPTY_T, act: RUNNER_T, kind: "runner" };
	}
}

/**
 * Resolve a flat level string the same way buildLevelMap does for base/act
 * (including stateful guard culling and multi-runner demotion).
 *
 * Guard culling characterization (matches main.js):
 *   1) Count all '0' into mapGuardCount
 *   2) On each '0' in row-major order: if (--mapGuardCount >= maxGuardLimit)
 *      demote act to EMPTY_T (do not spawn). Excess *first* guards are culled;
 *      the last maxGuardLimit guards survive.
 *
 * Runner demotion: first '&' keeps RUNNER_T; later '&' get act EMPTY_T.
 *
 * @param {string} levelMap length NO_OF_TILES_X * NO_OF_TILES_Y
 * @param {number} maxGuardLimit runtime maxGuard (MAX_NEW_GUARD=5 or MAX_OLD_GUARD=6)
 * @returns {{
 *   map: object[][],
 *   goldCount: number,
 *   runnerCount: number,
 *   guardCount: number,
 *   rawGuardCount: number,
 *   culledGuardCount: number,
 *   culledRunnerCount: number,
 *   runner: {x:number,y:number}|null,
 *   guards: {x:number,y:number}[]
 * }}
 */
function resolveLevelMap(levelMap, maxGuardLimit)
{
	var mapGuardCount = 0;
	var index = 0;
	var x, y, id, tile, act, kind;
	var goldCount = 0;
	var runnerCount = 0;
	var guardCount = 0;
	var culledGuardCount = 0;
	var culledRunnerCount = 0;
	var runnerPlaced = false;
	var runner = null;
	var guards = [];
	var map = [];

	// (1) count original guards - same first pass as buildLevelMap
	for (x = 0; x < NO_OF_TILES_X; x++) {
		map[x] = [];
		for (y = 0; y < NO_OF_TILES_Y; y++) {
			map[x][y] = null;
			if (levelMap.charAt(index++) == '0') mapGuardCount++;
		}
	}
	var rawGuardCount = mapGuardCount;

	// (2) resolve tiles with culling
	index = 0;
	for (y = 0; y < NO_OF_TILES_Y; y++) {
		for (x = 0; x < NO_OF_TILES_X; x++) {
			id = levelMap.charAt(index++);
			tile = parseLevelChar(id);
			act = tile.act;
			kind = tile.kind;

			if (kind === "guard") {
				if (--mapGuardCount >= maxGuardLimit) {
					act = EMPTY_T;
					kind = "empty"; // demoted - no spawn
					culledGuardCount++;
				} else {
					guardCount++;
					guards.push({ x: x, y: y });
				}
			} else if (kind === "runner") {
				if (runnerPlaced) {
					act = EMPTY_T;
					kind = "empty"; // demoted - no spawn
					culledRunnerCount++;
				} else {
					runnerPlaced = true;
					runnerCount = 1;
					runner = { x: x, y: y };
				}
			} else if (kind === "gold") {
				goldCount++;
			}

			map[x][y] = {
				base: tile.base,
				act: act,
				char: id,
				kind: kind
			};
		}
	}

	assert(mapGuardCount == 0, "Error: mapCuardCount design error !");

	return {
		map: map,
		goldCount: goldCount,
		runnerCount: runnerCount,
		guardCount: guardCount,
		rawGuardCount: rawGuardCount,
		culledGuardCount: culledGuardCount,
		culledRunnerCount: culledRunnerCount,
		runner: runner,
		guards: guards
	};
}

/**
 * Raw inventory parse (no maxGuard culling). Still demotes extra runners so
 * counts match "what would spawn" when maxGuard is unlimited.
 * Prefer resolveLevelMap(level, maxGuard) when characterizing buildLevelMap.
 */
function parseLevelMap(levelMap)
{
	return resolveLevelMap(levelMap, Number.POSITIVE_INFINITY);
}
