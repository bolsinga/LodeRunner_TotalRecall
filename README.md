Lode Runner - Total Recall
=======================================
## (超級運動員 - 全面回憶)

An HTML5 remake of the classic Lode Runner games, built with plain JavaScript and Canvas.

### * 3 Game Modes + 1 Demo Mode
<table>
<tr>
<td><b>1. Challenge Mode</b></td>
<td>Compete with other players.</td>
</tr>
<tr>
<td><b>2. Training Mode</b></td>
<td>Player can select any levels</td>
</tr>
<tr>
<td><b>3. Edit Mode</b></td>
<td>Player can create custom levels</td>
</tr>
<tr>
<td><b>4. Demo Mode</b></td>
<td>Demo passed levels</td>
</tr>

</table>

### * 5 Game Versions
<table>
<tr>
<td><b>1. <a target="_blank" rel="noopener" href="https://en.wikipedia.org/wiki/Lode_Runner">Classic Lode Runner</a></b></td>
<td>(150 Levels)</td>
<td>Difficulty: 3</td>
</tr>

<tr>
<td><b>2. <a target="_blank" rel="noopener" href="http://www.gb64.com/game.php?id=5906&d=42">Professional Lode Runner</a></b></td>
<td>(150 Levels)</td>
<td>Difficulty: 4</td>
</tr>

<tr>
<td><b>3. <a target="_blank" rel="noopener" href="http://www.vizzed.com/play/revenge-of-lode-runner-appleii-online-apple-ii-6223-game">Revenge of Lode Runner</a></b></td>
<td>(17 Levels)</td>
<td>Difficulty: 4</td>
</tr>

<tr>
<td><b>4. <a target="_blank" rel="noopener" href="https://www.omninet.net.au/~irhumph/loderunner.htm">Lode Runner Fan Book</a></b></td>
<td>(66 Levels)</td>
<td>Difficulty: 5</td>
</tr>

<tr>
<td><b>5. <a target="_blank" rel="noopener" href="https://en.wikipedia.org/wiki/Championship_Lode_Runner">Championship Lode Runner</a></b></td>
<td>(51 Levels)</td>
<td>Difficulty: 5</td>
</tr>
</table>

### * 2 Themes
<table>
<tr>
<td valign="middle">1.</td>
<td valign="middle"><img src="image/apple2.png" height="23" width="20"></td>
<td><b>APPLE-II</b></td>
</tr>
<tr>
<td valign="middle">2.</td>
<td valign="middle"><img src="image/commodore64.png" height="23" width="20"></td>
<td valign="middle"><b>Commodore 64</b></td>
</tr>
</table>

### * 2 Keyboard Control Modes

<table>
<tr>
<td valign="middle">1.</td>
<td valign="middle"><img src="image/repeatOn.png" height="24" width="24"></td>
<td valign="middle"><b>Repeat Actions On:</b> Like APPLE-II keyboard behavior</td>
</tr>
<tr>
<td valign="middle">2.</td>
<td valign="middle"><img src="image/repeatOff.png" height="24" width="24"></td>
<td valign="middle"><b>Repeat Actions Off:</b> Like NES keyboard behavior</td>
</tr>
</table>

### * Controls

**Move & dig** - several key layouts work at once, so pick whichever suits your keyboard:

| Action | Keys |
|--------|------|
| Move left | **&larr;** &nbsp;/&nbsp; **A** &nbsp;/&nbsp; **J** |
| Move right | **&rarr;** &nbsp;/&nbsp; **D** &nbsp;/&nbsp; **L** |
| Climb up | **&uarr;** &nbsp;/&nbsp; **W** &nbsp;/&nbsp; **I** |
| Climb down | **&darr;** &nbsp;/&nbsp; **S** &nbsp;/&nbsp; **K** |
| Dig left | **Z** &nbsp;/&nbsp; **Q** &nbsp;/&nbsp; **U** &nbsp;/&nbsp; **,** &nbsp;/&nbsp; **Y** |
| Dig right | **X** &nbsp;/&nbsp; **E** &nbsp;/&nbsp; **O** &nbsp;/&nbsp; **.** |

A gamepad can be used as well (toggle with **Ctrl+J**).

**Shortcuts** - hold **Ctrl** with the key:

| Key / control | Action |
|---------------|--------|
| **Esc** | Pause / help (temporarily reveals side icons if chrome is hidden) |
| **?** icon | Help overlay |
| **Ctrl+&minus;** / **Ctrl+=** | Slow down / speed up (Mac-friendly) |
| **Ctrl+&larr;** / **Ctrl+&rarr;** | Slow down / speed up (also works, but clashes with macOS Spaces) |
| **Ctrl+1** .. **Ctrl+5** | Pick a theme color slot |
| **Ctrl+S** | Sound on/off |
| **Ctrl+K** | Repeat-actions mode (APPLE-II vs NES key behavior) |
| **Ctrl+B** | Show/hide side chrome |
| **Ctrl+H** | Red-hat mode (guards that grab gold wear a red hat) |
| **Ctrl+J** | Gamepad on/off |
| **Ctrl+A** | Abort the current level |
| **Ctrl+R** | Abort the whole game |

### * Play on a Local Machine

The game needs to be served over HTTP (opening `lodeRunner.html` directly
from the filesystem won't work). Any static file server does; Python's
built-in one is the simplest:

1. Download and extract the source, then open a terminal in that directory.
2. Run `python3 -m http.server 8080`.
3. Open `http://127.0.0.1:8080/lodeRunner.html` in a browser.

On macOS/Linux, `./start.sh` does steps 2-3 for you (starts the server and
opens the page).

> **Note:** Changing the HTTP port makes the browser store "status" and
> "custom levels" data under a separate origin.

Offline disk-image extractors (not used at runtime) live under [`tools/`](tools/README.md).

### * <a target="_blank" rel="noopener" href="https://inindev.github.io/LodeRunner_TotalRecall/lodeRunner.html">Play Online</a>
------------------------------------
