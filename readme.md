<div align="center">
   <br/>
    <img src="https://i.postimg.cc/FRd8XcNH/zuzu.png" height="77" width="392" alt="Logo">
   <br/>
   <br/>
   <p>
      <em>
      Fast, powerful, cross-platform build system for Neovim.
      </em>
   </p>
</div>
<br/>


https://github.com/user-attachments/assets/c0d6c5e6-1375-44a3-81f5-7481857f1e4e


## 🎁 Features
  * ### [🎨 customizable build profiles](#-profiles)
	* write multiple different build scripts in one profile
	* project-wide, file-specific, or even global profiles
	* restrict profiles to specific filetypes/depth
	* create generalized setup code to apply to all builds
  * ### [🧠 smart profile resolution](#-profile-resolution)
	* if multiple profiles apply to one file, zuzu will intelligently choose the best one
	* allows you to create a "fallback" profile that will apply to every file for a specific language, without setup
  * ### [✔  quickfix integration!](#-quickfix)
	* view runtime errors as [diagnostic messages](#-quickfix) in your source code
	* jump between lines of an error traceback quickly 
  * ### [💲 hooks! (dynamic environment variables)](#-hooks)
	* built-in core hooks for things like `$file`, `$dir`, `$parent`, etc.
	* create your own core hooks that will be always be initialized in every build
	* interactive interface for editing hooks
	* create [hook choices](#hook-choices) to easily choose from a list of pre-defined options
  * ### [🖥 versatile display options](#-display-strategies)
	* create your own display strategy (command mode, split terminal right, split terminal below, etc.)
	* bind keymaps to different display strategies
	* you can even run builds in the background!
  * ### [⚡ blazingly fast (<1ms of overhead)](#-benchmarks)
	* build scripts are also cached to avoid writing files several times on repeated runs
  * ### 🌐 cross-platform!
	* supports Windows, Linux, MacOS, and other UNIX-based systems
 

## Table of Contents

* [Installation](#--installation)
    * [Requirements](#-requirements)
    * [Configuration](#--configuration)
* [Profiles](#-profiles)
    * [Creating a New Profile](#--creating-a-new-profile)
    * [Editing Profiles](#--editing-profiles)
    * [Deleting Profiles](#-deleting-profiles)
    * [Profile Resolution](#-profile-resolution)
* [Hooks](#-hooks)
    * [Core Hooks](#core-hooks)
    * [Hook Choices](#hook-choices)
* [Customizing Builds](#%EF%B8%8F-customizing-builds)
    * [Naming Builds](#-naming-builds)
    * [Quickfix](#-quickfix)
        * [Assigning a Compiler](#assigning-a-compiler)
        * [Registering a New Compiler](#registering-a-new-compiler)
* [Reflect](#-reflect)
* [Display Strategies](#-display-strategies)
    * [Background Mode](#-background-mode)
    * [Terminal Mode vs Buffer Mode](#-terminal-mode-vs-buffer-mode)
* [API](#-api)
* [Benchmarks](#-benchmarks)
* [Highlight Groups](#-highlight-groups)

## ⚒  Installation

### ✅ Requirements

 - neovim 0.10.0+ (but will likely work on older versions)

> [!Important]
> If you are on Windows, you will need to configure Neovim to use Powershell as its shell. Add the following to your `init.lua`:

<details>
<summary>init.lua</summary>

```lua
vim.o.shell = 'powershell.exe'
vim.o.shellxquote = ''
vim.o.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command '
vim.o.shellquote = ''
vim.o.shellpipe = '| Out-File -Encoding UTF8 %s'
vim.o.shellredir = '| Out-File -Encoding UTF8 %s'
```

</details>

<br/>

zuzu.nvim can be installed with the usual plugin managers:

#### lazy.nvim
```lua
{
	"gitpushjoe/zuzu.nvim",
	opts = {
		--- add options here
	}
}
```

#### packer.nvim
```lua
use {
	"gitpushjoe/zuzu.nvim",
	config = function ()
		require("zuzu").setup({
			--- add options here
		})
	end
}
```

<br/>

### ⚙  Configuration

<details>
<summary>Default Configuration</summary>

```lua
require("zuzu").setup({
	build_count = 4,
	display_strategy_count = 4,
	keymaps = {
		build = {
			{ "zu", "ZU", "zU", "Zu" },
			{ "zv", "ZV", "zV", "Zv" },
			{ "zs", "ZS", "zS", "Zs" },
			{ "zb", "ZB", "zB", "Zb" },
		},
		reopen = {
			"z.",
			'z"',
			"z:",
		},
		new_profile = "z+",
		new_project_profile = "z/",
		edit_profile = "z=",
		edit_all_applicable_profiles = "z?",
		edit_all_profiles = "z*",
		edit_hooks = "zh",
		qflist_prev = "z[",
		qflist_next = "z]",
		stable_toggle_qflist = "z\\",
		toggle_qflist = "z|",
	},
	display_strategies = {
		require("zuzu.display_strategies").command,
		require("zuzu.display_strategies").split_terminal(
			"vertical rightbelow", -- Split modifiers
			true                   -- Use "buffer mode"
		),
		require("zuzu.display_strategies").split_terminal(
			"horizontal rightbelow",
			true
		),
		require("zuzu.display_strategies").background(
			--- Delay between each elapsed time update in milliseconds
			1000 / 8
		),
	},
	path = {
		root = require("zuzu.platform").join_path(
			vim.fn.stdpath("data"), 
			"zuzu"
		),
		atlas_filename = "atlas.json",
		last_stdout_filename = "stdout.txt",
		-- Note: last_stderr_filename is not used on Windows
		last_stderr_filename = "stderr.txt",
		compiler_filename = "compiler.txt",
		reflect_filename = "reflect.txt",
	},
	core_hooks = {
		-- Note: these are actually "env:file", "env:dir", etc. on Windows
		{ "file", require("zuzu.hooks").file },
		{ "dir", require("zuzu.hooks").directory },
		{ "parent", require("zuzu.hooks").parent_directory },
		{ "base", require("zuzu.hooks").base },
		{ "filename", require("zuzu.hooks").filename },
	},
	colors = {
		reopen_stderr = require("zuzu.colors").bright_red,
		reflect = require("zuzu.colors").bright_yellow,
	},
	zuzu_function_name = "zuzu_cmd",
	prompt_on_simple_edits = false,
	hook_choices_suffix = "__c",
	compilers = {
		-- https://vi.stackexchange.com/a/44620
		{ "python3", '%A %#File "%f"\\, line %l\\, in %o,%Z %#%m' },
		{ "lua", "%E%\\\\?lua:%f:%l:%m,%E%f:%l:%m" },
		-- https://github.com/felixge/vim-nodejs-errorformat/blob/master/ftplugin/javascript.vim
		-- Note: This will also work for bun.
		{
			"node",
			[[%AError: %m,%AEvalError: %m,%ARangeError: %m,%AReferenceError: %m,%ASyntaxError: %m,%ATypeError: %m,%Z%*[\ ]at\ %f:%l:%c,%Z%*[\ ]%m (%f:%l:%c),%*[\ ]%m (%f:%l:%c),%*[\ ]at\ %f:%l:%c,%Z%p^,%A%f:%l,%C%m,%-G%.%#]],
		},
		{
			"bash",
			"%E%f: line %l: %m",
		},
	},
	qflist_as_diagnostic = true,
	reverse_qflist_diagnostic_order = false,
	qflist_diagnostic_error_level = "WARN",
	write_on_run = true,
	fold_profiles_in_editor = true,
	reflect = false,
	newline_after_reflect = true,
	newline_before_reopen = false,
	enter_closes_buffer = true,
	reopen_reflect = true,
})
```

|Key |Explanation |
|-|-|
|`build_count`|The number of different builds for each [profile](#-profiles).
|`display_strategy_count`|The number of [display strategies](#-display-strategies). The 4 strategies by default are "command-mode" `:!source run.sh`, split-right-terminal, and split-below-terminal, and background.
|`keymaps.build`|A 2D list of keymaps. The first row is mapped to the first display strategy, the second row to the second, and so on. The first keymap in each row is mapped to build #1, the second to build #2, and so on. So, for example, pressing `"zV"` will run the 3rd build in the current profile, with the 2nd build display style (split-right-terminal). Use `""` to not bind any keymap.
|`keymaps.reopen`|Every time zuzu is run, its output is saved to the `path.root` directory at `path.last_output_filename`. Pressing `keymap.reopen[i]` will show the output from the last time zuzu was run, using display strategy #`i`.
|`keymaps.new_profile`|Creates a new profile. Sets the root to the current file and sets the depth to 0.
|`keymaps.new_project_profile`|Creates a new profile. Sets the root to the *directory* of the current file and sets the depth to -1 (any depth).
|`keymaps.edit_profile`|Shows the profile for the current file (the most applicable profile).
|`keymaps.edit_all_applicable_profiles`|Shows all applicable profiles for the current file, in order from least applicable to most.
|`keymaps.edit_all_profiles`|Shows all profiles.
|`keymaps.edit_hooks`|Opens an interactive menu for updating a [hook](#-hooks).
|`keymaps.qflist_prev`|Opens the quickfix list if it's closed, and jumps to the previous error (see [:cprevious](https://neovim.io/doc/user/quickfix.html#%3Acprevious)).
|`keymaps.qflist_next`|Opens the quickfix list if it's closed, and jumps to the nextious error (see [:cnext](https://neovim.io/doc/user/quickfix.html#%3Acnextious)).
|`keymaps.stable_toggle_qflist`|Toggles the state of the quickfix list, keeping the cursor in the current window.
|`keymaps.toggle_qflist`|Toggles the state of the quickfix list, putting the cursor in the quickfix list. Also toggles whether quickfix diagnostics are shown/hidden.
|`display_strategies`|List of [display strategies](#-display-strategies). 
|`path.root`|The root directory zuzu will use to save any files its creates.
|`path.atlas_filename`|The filename for the atlas saved to `path.root`.
|`path.last_stdout_filename`|The filename to save the stdout to from the last time zuzu was run.
|`path.last_stderr_filename`|The filename to save the stderr to from the last time zuzu was run.
|`path.compiler_filename`|The filename to save the [compiler name](#-quickfix) to from the last time zuzu was run.
|`path.reflect_filename`|The filename to save the source code of the build being run to. See [Reflect](#-reflect).
|`core_hooks`|A list of tuples. The first item in each tuple is the name of the [hook](#-hook), and the second item is a callback to get the value of the hook. For example, by default, the hooks `$file` and `$dir` will be automatically initialized to the current file and directory, respectively, before every build.
|`zuzu_function_name`|To run a build, zuzu generates a shell file (`.sh` on UNIX-based, `.ps1` on windows) and puts the build script in a function. This is the name of the function.
|`colors.reopen_stderr`|The color to display errors in when reopening the output from the last run. Cross-platform. See [here](./lua/zuzu/colors.lua) for the list of all available colors.
|`colors.reflect`|The color to display the source code of the build being run in. Cross-platform. See [Reflect](#-reflect).
|`prompt_on_simple_edits`|If `false`, zuzu will skip the confirmation prompt on simple edits (no overwrites or deletes).
|`hook_choices_suffix`|See [Hooks](#-hooks).
|`compilers`|A list of { compiler-name, [errorformat](https://neovim.io/doc/user/quickfix.html#errorformat) } tuples. When running a build, zuzu will search this list first before running [:compiler](https://neovim.io/doc/user/quickfix.html#%3Acompiler). See [Quickfix](#-quickfix).
|`qflist_as_diagnostic`|If `true`, the quickfix list locations will also be shown as diagnostics.
|`reverse_qflist_diagnostic_order`|If `true`, then the last quickfix diagnostic will be labeled as #1 instead of the first. The direction of `qflist_`{`prev`/`next`} will also be swapped.
|`qflist_diagnostic_error_level`|The [severity](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.severity) to use for the quickfix list diagnostics.
|`write_on_run`|If `true`, the current file will be saved before running a build.
|`fold_profiles_in_editor`|If `true`, whenever multiple profiles are shown in the profile editor, they will all be folded, except for the most relevant profile.
|`reflect`|If `true`, the source code of the build being run will be displayed, before the command runs. See [Reflect](#-reflect).
|`newline_after_reflect`|If `true` and `reflect` is `true`, a newline will be added after displaying the source code of the build. See [Reflect](#-reflect).
|`newline_before_reopen`|If `true`, a newline will be added before the output of reopen.
|`enter_closes_buffer`|If `true` and the reopen display strategy returns a buffer, then pressing Enter in the buffer will close it.

</details>

## ⌨ Profiles

A **build** is a series of shell commands detailing how your code should be run. For example:

```sh
echo "Running!"
python3 ./main.py
```

A **profile** is a collection of independent, yet related builds. (By default every profile can have a maximum of four builds.) This is an example of a profile with four builds:

```sh
### {{ root: * }}
### {{ filetypes: py }}
### {{ depth: -1 }}
### {{ hooks }}
export input=input.txt

### {{ setup }}
cd $dir

### {{ zu }}
### {{ name: primary_build }}
python3 $file

### {{ ZU }}
### {{ name: type_checking }}
mypy $file

### {{ zU }}
### {{ name: benchmark }}
time -p python3 $file

### {{ Zu }}
### {{ name: tests }}
python3 -m unittest -b $file

```

<br/>

### 📦  Creating a New Profile

> [!Note]
> On UNIX-based systems, use Bash syntax and commands in the profile editor. On Windows, use Powershell syntax and commands.

You can use `z+` (by default) or `require("zuzu").new_profile()` to create a new build profile, using the current file as a template. For example, if you were editing the file `/home/user/project/main.cpp` and pressed `z+`, you would see the following:

```sh
### {{ root: /home/user/project/main.cpp }}
### {{ filetypes: cpp }}
### {{ depth: 0 }}
### {{ hooks }}
### {{ setup }}


### {{ zu }}


### {{ ZU }}


### {{ zU }}


### {{ Zu }}


```

Because the depth is set to 0, this profile will only apply to the current file. If, for example, you wanted to create a profile that applied to all files in `/home/user/project/`, an easy way to do that is with `z/` or `require("zuzu").new_project_profile()`.

```sh
### {{ root: /home/user/project }}
### {{ filetypes: cpp }}
### {{ depth: -1 }}
### {{ hooks }}
### {{ setup }}


### {{ zu }}


### {{ ZU }}


### {{ zU }}


### {{ Zu }}


```

This sets the `depth` to `-1`, which will make your profile apply to all files under `root`. 
If you want your profile to apply to multiple filetypes, comma-separate them without spaces:

```sh
### {{ filetypes: cpp,cc,hpp,hh }}
```

You can alternatively use `*` to specify all filetypes:

```sh
### {{ filetypes: * }}
```

Hooks are covered in [this section](#-hooks).

Everything inside the setup section will be executed before a build, regardless of which build is chosen. Here is an example for a C++ project:

```sh
### {{ root: /home/user/project }}
### {{ filetypes: * }}
### {{ depth: -1 }}
### {{ hooks }}
### {{ setup }}
cd $dir
rm -rf output
g++ -std=c++17 ./main.cpp -o ./main.o
echo "Compiled!"

### {{ zu }}


### {{ ZU }}


### {{ zU }}


### {{ Zu }}


```

> [!Note]
> `$dir` is explained [here](#core-hooks). 

Finally, zuzu, by default, allows four builds for each profile. These builds are labelled by the keymap used to trigger them. For example, if you create a profile such as this one:

```sh
### {{ root: /home/user/project }}
### {{ filetypes: * }}
### {{ depth: -1 }}
### {{ hooks }}
### {{ setup }}
cd $dir
rm -rf output
g++ -std=c++17 -g ./main.cpp -o ./main
echo "Compiled!"

### {{ zu }}
./main blur 5 ./apple.pgm ./output/apple.pgm 

### {{ ZU }}
./main blur 15 ./apple.pgm ./output/apple.pgm 

### {{ zU }}
./main blur 5 ./pear.pgm ./output/pear.pgm 

### {{ Zu }}
./main blur 15 ./pear.pgm ./output/pear.pgm 

```

and then save the profile with `:w`, you can press `zu` to run the first build command (blur the apple image). To cancel the creation of the profile, you can use `:q` and then select the "exit" option, or use `:bd!` or `:bn` or `:bp`.

> [!Tip]
> When creating a new profile, you can copy and paste the template to create multiple profiles for different roots/depths/filetypes at once. This is also true when editing a profile.

<br/>

### ✏  Editing Profiles

To edit a profile after it's been created, you can use `z=` to open it. This will open the [most applicable profile](#-profile-resolution) for the currently-open file. `z?` will open all profiles that apply to the current file, in order from least applicable to most. `z*` will open all profiles. To apply your changes, use `:w`.

<br/>

### 🗑 Deleting Profiles

To delete a profile, simply open the profile using one of the methods above. Deleting the text associated with the profile, then hitting `:w`, will delete the profile. So, for example, if you wanted to delete all profiles, first open all profiles with `z*`, delete everything in the buffer, then confirm with `:w`.

<br/>

### 🔍 Profile Resolution

As you may have noticed, it's very possible for one file to have multiple profiles that apply to it. In this case, zuzu will choose the most applicable profile to use based on the following criteria, in order of importance:

1. **Select the profiles with the closest root**. So for a file like `/home/user/project/main.cpp`, profiles with root `/home/user/project/main.cpp` would be considered first. If there were no profiles with that root that matched, then profiles with root `/home/user/project` would be considered, then `/home/user/`, and so on.
2. Then, **select the profiles with the fewest number of filetypes.** So for a `.cpp` file, a profile with filetypes `cpp,h` would be considered before a profile with filetypes `cpp,c,txt`.
3. Finally, **select the profiles with the lowest depth** (treating -1 as infinity). Using the previous `main.cpp` example, if there are two profiles in `/home/user/project`, but one of them has depth 2 and the other has depth -1, then the profile with depth 2 would be selected.

<br/>

## 💲 Hooks

Hooks are environment variables.

If you define environment variables in the `{{ hooks }}` section, you can easily modify them *without* opening up the entire profile, by using `zh`. It will open up a window for you to select the hook you want to change, and then prompt you for the new value (see below). Hooks will be accessible in both `{{ setup }}` and the build commands.

![Example](https://i.imgur.com/83V30sr.png)

#### UNIX version

```sh
### {{ root: /home/user/project }}
### {{ filetypes: * }}
### {{ depth: -1 }}
### {{ hooks }}
export filter="blur"
export image="apple"
export level=15

### {{ setup }}
cd $dir
rm -rf output
g++ -std=c++17 -g ./main.cpp -o ./main
echo "Compiled!"

### {{ zu }}
echo "Applying filter $filter to $image with level $level"
./main $filter $level ${image}.pgm ./output/${image}.pgm 

### {{ ZU }}


### {{ zU }}


### {{ Zu }}


```

#### Windows version

```ps1
### {{ root: /home/user/project }}
### {{ filetypes: * }}
### {{ depth: -1 }}
### {{ hooks }}
$filter = "blur"
$image = "apple"
$level = 15

### {{ setup }}
Set-Location -Path $dir
Remove-Item -Recurse -Force "output"
g++ -std=c++17 -g ./main.cpp -o ./main
Write-Output "Compiled!"

### {{ zu }}
Write-Output "Applying filter $filter to $image with level $level"
./main $filter $level "$image.pgm" "./output/$image.pgm"

### {{ ZU }}


### {{ zU }}


### {{ Zu }}


```

<br/>

### Core Hooks

Some hooks are available by default, and are automatically initialized every time a build command is run. These are called "core hooks" and can be changed, renamed, or added to in the `setup()` command. To create a new hook, simply pass a tuple to the `core_hooks` list of `setup()` with the first item being the name of the hook, and the second item being a function that returns the hook's value. The default core hooks are as follows:

|Hook name|Hook value
|-|-|
|`$file`|Always set to the absolute path of the current file.
|`$dir`|Always set to the directory of the current file.
|`$parent`|Always set to the parent directory of the current file.
|`$base`|Always set to the basename of the current file, without the extension.
|`$filename`|Always set to the basename of the current file, including the extension.

<br/>

### Hook Choices

If you declare a hook, but you know in advance that there are only a handful of values it will reasonably have, you can declare another hook that stores the choices for it in an array. This choices hook should have the same name as the original hook but end in `"__c"` (this can be changed). (Note: if on Windows, use the [Powershell array syntax](https://ss64.com/ps/syntax-arrays.html).) Then, when you go to edit the hook, it will display those options in a window for you to easily select.

![Example](https://i.imgur.com/iDJ5BlS.png)

```sh
### {{ root: /home/user/project }}
### {{ filetypes: * }}
### {{ depth: -1 }}
### {{ hooks }}
export filter="blur"
export filter__c=("blur" "saturate" "posterize" "brighten")
export image="apple"
export image__c=(apple dog vacaction)
export level=15
export level__c=(0 5 15 100 150 300)
export optimization="-O3"
export optimization__c=(-O0 -O1 -O2 -O3)
export debug=
export debug__c=("-DDEBUG" "")

### {{ setup }}
cd $dir
rm -rf output
g++ -std=c++17 $debug -g ./main.cpp -o ./main
echo "Compiled!"

### {{ zu }}
echo "Applying filter $filter to $image with level $level"
./main $filter $level ${image}.pgm ./output/${image}.pgm 

### {{ ZU }}


### {{ zU }}


### {{ Zu }}


```

<br/>

## 🖌️ Customizing Builds

### 🖋 Naming Builds

You can also give builds a name (alphanumeric characters only, no spaces), like so:

```sh
### {{ zu }}
### {{ name: blur5 }}
./main blur 5 apple.pgm ./output/apple.pgm 
```

This will give the build a custom filename in the builds folder. Doing this has two primary benefits:

 - You can clearly see the name of the build being run, as opposed to something like `/home/.../zuzu/1.sh`, and it might improve readability in the profile editor.
 - zuzu implements caching based on filenames. If you frequently switch between the first build of two different profiles, then zuzu would have to write the build commands to that `1.sh` file each time. However, if you give the two builds different names, then zuzu will only have to load each build in once.

<br/>

### ✅ Quickfix

> [!Note]
> This feature is not supported on Windows.

Similarly to [:make](https://neovim.io/doc/user/quickfix.html#%3Amake), zuzu.nvim allows you to assign the name of a compiler to a profile or build. (Neovim comes with quite a few compilers already configured. Type `:compiler` and then press [Tab] to see them.) Whenever a build is executed, the stderr output is always written to disk in the zuzu folder under the stderr filename specified in `setup()`. After executing a build, pressing `z\` or `z|` (or also `z]` or `z[`) will parse the stderr file using the compiler assigned to the profile or build, and open the quickfix list. (The syntax for doing so is below the image.) Here is an example of how this will appear in Neovim:

![Example](https://i.imgur.com/KW4hddg.png)

> [!Tip]
> The numbers of the diagnostics count in the opposite direction of their appearances in the quickfix list. This can be preferable for compilers like Python, where the line closest to the source of the error is printed last rather than first. To reverse the order like this, use the `reverse_qflist_diagnostic_order` option in `setup()`. 

<br/>

#### Assigning a Compiler

Compilers can be assigned either to all builds in a profile, or to a specific build. If the compiler assigned to a build is different from the compiler assigned to the profile, then the build-specific compiler will be chosen. To assign a compiler to a profile, insert `### {{ compiler: name-of-the-compiler }}` **under** the root header, but **above** the filetypes header. To assign a compiler to a build, insert the header **below** the keymap header, and **below** the name header, if there is one.

```sh
### {{ root: * }}
### {{ compiler: python3 }}
### {{ filetypes: py }}
### {{ depth: -1 }}
### {{ hooks }}
### {{ setup }}
cd $dir

### {{ zu }}
# This build will use the "python3" compiler for stderr parsing.
python3 $file

### {{ ZU }}
### {{ compiler: pyunit }}
# This will override the "python3" compiler above, and use the "pyunit" compiler.
python3 -m unittest discover -s tests
```

<br/>

#### Registering a New Compiler

If the compiler you use isn't available under `:compiler` (or you dislike its implementation), you can register it. Simply add the name of the compiler and its [errorformat](https://neovim.io/doc/user/quickfix.html#errorformat) under the `compilers` parameter in `setup()`. errorformats for Python3, lua, node, and bash have been provided, but if you have found/written an errorformat for your language, feel free to submit a pull request.

## 💭 Reflect

> [!Note]
> This feature requires `envsubst` on UNIX-based systems, which is not installed on MacOS by default.
> This can be installed via homebrew:

<details>
<summary>envsubst install command</summary>

```sh
brew install gettext
brew link --force gettext
```

</details>

Reflect is a feature that displays the source code of the build command being run, before the output of the command. It also replaces hooks like `$file` with their actual values. Furthermore, the build command being run is stored using the `path.reflect_filename` option in the config, so that it can be displayed when reopening the last build output (if the `reopen_reflect` option is enabled).

<br/>

## 🖥 Display Strategies

Display strategies control the way that build commands are run in Neovim. They are functions that take in the following arguments:

```lua
---@param shell_cmd string
---@param profile Profile
---@param build_idx integer
---@param last_stdout_path string
---@param last_stderr_path string
---@param is_reopen boolean?
local function my_strategy(
	shell_cmd, 
	profile, 
	build_idx, 
	last_stdout_path, 
	last_stderr_path,
	is_reopen
)
```

The four display strategies that are registered by default are listed [here](#--configuration) and their implementations can be found [here](./lua/zuzu/display-strategies).

To use your own custom display strategy function, simply pass it to the `display_strategies` list in the `setup()` function.

<br/>

### ⏳ Background Mode

The background display strategy will create a new buffer, and instantly switch back to the previous buffer (without flashing the screen) and execute the build in the "background buffer". This display strategy can be accessed via `require("zuzu.display_strategies").background()`. This is an alias of the equivalent `require("zuzu.background").display_strategy()`, which returns a display strategy function, created using the arguments passed to it:

```lua
-- lua/zuzu/background.lua

---@class MessageType: string
local message_types = {
	SUCCESS = "SUCCESS",
	FAILURE = "FAILURE",
	UPDATE = "UPDATE",
	NORMAL = "NORMAL",
}

---@param loop_delay_ms integer?
---@param print_func (fun(text: string, message_type: MessageType, is_intiial_message: boolean?): any)?
---@param on_finish (fun(is_success: boolean): any)?
require("zuzu.background").display_strategy(loop_delay_ms, print_func, on_finish)
```

The purpose of each argument is as follows:

 - `loop_delay_ms`
	- As the build executes in the background, zuzu will periodically display updates, showing the current build being run and the elapsed time. This argument is the amount of delay between each update, in milliseconds. **Defaults to `1000 / 8` (or 125ms).**
 - `print_func`
	- This is the method used to print the updates. It should be a function that takes in the `text` of the update, a `message_type` (see the enum definition above), and an `is_initial_message` boolean that will be `true` on the initial message. **Defaults to `require("zuzu.background").print_functions.notify`**, which will use your Neovim notify system to display the updates. An alternative is provided in `require("zuzu.background").print_functions.nvim_echo`, which will use [nvim_echo](https://neovim.io/doc/user/api.html#nvim_echo%28%29) to display the updates.
 - `on_finish`
	- This is the function that will be called when the background build finishes executing. **Defaults to `function() end`.**

<br/>

### 🧩 Terminal Mode vs Buffer Mode

If a display strategy returns `nil`, then it is in "terminal mode" and if it returns an integer (the ID of the buffer to use), it is in "buffer mode". Buffer mode is required for the `enter_closes_buffer` conifg option to work. Furthermore, buffer mode display strategies will have more consistent colors. If using buffer mode, do not execute the build command in the display strategy if `is_reopen` is `true`, as zuzu will automatically populate the buffer with the correct text.

<br/>

## 🔧 API

```lua
-- Runs build #`build_idx` on the current file.
---@param build_idx integer
---@param display_strategy_idx integer
require("zuzu").run(build_idx, display_strategy_idx)

-- Displays the output from the last time zuzu was run.
---@param build_idx integer
---@param display_strategy_idx integer
require("zuzu").reopen(display_strategy_idx)

-- Opens the profile editor, using the current file as a template for creating
-- a new profile.
require("zuzu").new_profile()

-- Opens the profile editor, using the directory the current file is in as a 
-- template for creating a new profile.
require("zuzu").new_project_profile()

-- Opens the profile editor on the most applicable profile for the current 
-- file.
require("zuzu").edit_profile()

-- Opens the profile editor on all profiles that apply to the current file.
require("zuzu").edit_all_applicable_profile()

-- Opens the profile editor on all profiles.
require("zuzu").edit_all_profiles()

-- Opens a prompt to enter a new name for a hook, or opens a window if the hook
-- has choices. If you want to directly set a hook with choices, skipping the
-- window, prepend "zuzu-direct-set: " to the beginning of `hook_name`.
---@param hook_name string
require("zuzu").edit_hook(hook_name)

-- Opens a window to edit all hooks for the current file.
require("zuzu").edit_hooks()

-- Assigns `hook_val` to the hook with the name `hook_name`.
-- @param hook_name string
-- @param hook_val string
require("zuzu").set_hook(hook_name, hook_val)

-- Opens the qflist if it's closed, and closes it if it's open. Also hides 
-- quickfix-related diagnostics, if they are enabled. If `is_stable` is `true`,
-- then the cursor will stay in the current buffer. If `is_stable` is `false`
-- or `nil`, the cursor will move to the quickfix list.
---@param is_stable boolean?
require("zuzu").toggle_qflist(is_stable)

-- Moves forward or backwards one item in the quickfix list, with wrap-around,
-- based on `is_next`.
---@param is_next boolean
require("zuzu").qflist_prev_or_next(is_next)

-- Prints the current zuzu verison.
require("zuzu").version()
```

<br/>

## ⏰ Benchmarks

Compared to just using the typical command-mode in Neovim `(:!)`, zuzu.nvim takes 0.1-0.5ms **longer** to run build commands. This includes the time taken for the initial write; note that if the same build is repeatedly run in the same file, zuzu.nvim will elide the redundant writes. After modifying the plugin to write on each build run, the overhead increases to about 0.4-0.6ms.

```lua
local zuzu_diffs = {}
local vim_cmd_diffs = {}
local last_output_path = require("zuzu.platform").join_path(
	vim.fn.stdpath("data"),
	"zuzu",
	"stdout.txt"
)
local count = 10

function ZuzuTest(use_zuzu)
    local diffs = use_zuzu and zuzu_diffs or vim_cmd_diffs
	for i = 1, count do
		if i ~= 1 then
			assert(io.popen("sleep 1")):close()
		end
		local handle = assert(io.popen("date +%s%6N"))
		local start_text = handle:read("*a")
		if use_zuzu then
		    require("zuzu").run(1, 1)
		else
		    vim.cmd("!date +\\%s\\%6N >" .. last_output_path)
		end
		local handle2 = assert(io.open(last_output_path, "r"))
		local end_text = handle2:read("*a")
		start_text = string.sub(start_text, 5)
		end_text = string.sub(end_text, 5)
		table.insert(diffs, tonumber(end_text) - tonumber(start_text))
		local sum = 0
		for _, diff in ipairs(diffs) do
			io.write(diff .. " ")
			sum = sum + diff
		end
		print("avg = " .. sum / #diffs .. "us")
		handle2:close()
		handle:close()
	end
end

vim.api.nvim_set_keymap(
	"n",
	"<leader>zt",
	":lua ZuzuTest(true)<CR>",
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>zT",
	":lua ZuzuTest(false)<CR>",
	{ noremap = true, silent = true }
)
```

```sh
### {{ root: * }}
### {{ filetypes: * }}
### {{ depth: -1 }}
### {{ hooks }}
### {{ setup }}

### {{ zu }}
date +%s%6N
```

<br/>

## 🖍 Highlight Groups

```
ZuzuCreate
ZuzuReplace
ZuzuOverwrite
ZuzuDelete
ZuzuHighlight
ZuzuBackgroundRun
ZuzuSuccess
ZuzuFailure
```
