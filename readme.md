# zuzu.nvim

Fast, customizable, powerful build system for Neovim.

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
* [Naming Builds](#-naming-builds)
* [Display Strategies](#-display-strategies)

## ⚒  Installation

### ✅ Requirements

 - neovim 0.10.0+ (but will likely work on older versions)

> [!Important]
> If you are on Windows, you will need to configure Neovim to use Powershell as its shell. Add the following to your `init.lua`:

```lua
vim.o.shell = 'powershell.exe'
vim.o.shellxquote = ''
vim.o.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command '
vim.o.shellquote = ''
vim.o.shellpipe = '| Out-File -Encoding UTF8 %s'
vim.o.shellredir = '| Out-File -Encoding UTF8 %s'
```

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

Default configuration:

```lua
require("zuzu").setup({
	build_count = 4,
	display_strategy_count = 3,
	keybinds = {
		build = {
			{ "zu", "ZU", "zU", "Zu" },
			{ "zv", "ZV", "zV", "Zv" },
			{ "zs", "ZS", "zS", "Zs" },
		},
		reopen = {
			"z,",
			'z"',
			"z:",
		},
		new_profile = "z+",
		new_project_profile = "z/",
		edit_profile = "z=",
		edit_all_applicable_profiles = "z?",
		edit_all_profiles = "z*",
		edit_hooks = "zh",
	},
	display_strategies = {
		require("zuzu.display_strategies").command,
		require("zuzu.display_strategies").split_right,
		require("zuzu.display_strategies").split_below,
	},
	path = {
		root = require("zuzu.platfom").join_path(vim.fn.stdpath("data"), "zuzu"),
		atlas_filename = "atlas.json",
		last_output_filename = "last.txt",
	},
	core_hooks = {
		{ "file", require("zuzu.hooks").file },
		{ "dir", require("zuzu.hooks").directory },
		{ "parent", require("zuzu.hooks").parent_directory },
		{ "base", require("zuzu.hooks").base },
		{ "filename", require("zuzu.hooks").filename },
	},
	zuzu_function_name = "zuzu_cmd",
	prompt_on_simple_edits = false,
	hook_choices_suffix = "__c",
})
```

|Key |Explanation |
|-|-|
|`profile_count`|The number of different builds for each [profile](#-profiles).
|`display_strategy_count`|The number of [display strategies](#-display-strategies). The 3 strategies by default are "command-mode" `:!source run.sh`, split-right-terminal, and split-below-terminal.
|`keybinds.build`|A 2D list of keybinds. The first row is mapped to the first display strategy, the second row to the second, and so on. The first keybind in each row is mapped to build #1, the second to build #2, and so on. So, for example, pressing `"zV"` will run the 3rd build in the current profile, with the 2nd build display style (split-right-terminal). Use `""` to not bind any keybind.
|`keybinds.reopen`|Every time zuzu is run, its output is saved to the `path.root` directory at `path.last_output_filename`. Pressing `keybind.reopen[i]` will show the output from the last time zuzu was run, using display strategy #`i`.
|`keybinds.new_profile`|Creates a new profile. Sets the root to the current file and sets the depth to 0.
|`keybinds.new_project_profile`|Creates a new profile. Sets the root to the *directory* of the current file and sets the depth to -1 (any depth).
|`keybinds.edit_profile`|Shows the profile for the current file (the most applicable profile).
|`keybinds.edit_all_applicable_profiles`|Shows all applicable profiles for the current file. Note that these profiles are *not* shown in any order.
|`keybinds.edit_all_profiles`|Shows all profiles.
|`keybinds.edit_hooks`|Opens an interactive menu for updating a [hook](#-hooks).
|`display_strategies`|List of [display strategies](#-display-strategies). 
|`path.root`|The root directory zuzu will use to save any files its creates.
|`path.atlas_filename`|The filename for the atlas saved to `path.root`.
|`path.last_output_filename`|The filename to save the output of the last time zuzu was run to.
|`core_hooks`|A list of tuples. The first item in each tuple is the name of the [hook](#-hook), and the second item is a callback to get the value of the hook. For example, by default, the hooks `$file` and `$dir` will be automatically initialized to the current file and directory, respectively, before every build.
|`zuzu_function_name`|To run a build, zuzu generates a shell file (`.sh` on UNIX-based, `.ps1` on windows) and puts the build script in a function. This is the name of the function.
|`prompt_on_simple_edits`|Determines whether or not to show a confirmation prompt on simple edits (no overwrites or deletes).
|`hook_choices_suffix`|See [Hooks](#-hooks).

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

You can use `z+` (by default) or `require("zuzu").new_profile()` to create a new build profile, using the current file as a template. For example, in a file such as `/home/user/project/main.cpp` (with default settings), you would see the following:

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

Finally, zuzu, by default, allows four builds for each profile. These builds are labelled by the keybind used to trigger them. For example, if you create a profile such as this one:

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

To edit a profile after it's been created, you can use `z=` to open it. This will open the [most applicable profile](#-profile-resolution) for the currently-open file. `z?` will open all profiles that apply to the curent file, but they (currently) won't be listed in any particular order. `z*` will open all profiles. To apply your changes, use `:w`.

<br/>

### 🗑 Deleting Profiles

To delete a profile, simply open the profile using one of the methods above. Deleting the text associated with the profile, then hitting `:w`, will delete the profile. So, for example, if you wanted to delete all profiles, first open all profiles with `z*`, delete everything in the buffer, then confirm with `:w`.

<br/>

## 🔍 Profile Resolution

As you may have noticed, it's very possible for one file to have multiple profiles that apply to it. In this case, zuzu will choose the most applicable profile to use based on the following criteria, in order of importance:

1. **Select the profiles with the closest root**. So for a file like `/home/user/project/main.cpp`, profiles with root `/home/user/project/main.cpp` would be considered first. If there were no profiles with that root that matched, then profiles with root `/home/user/project` would be considered, then `/home/user/`, and so on.
2. Then, **select the profiles with the fewest number of filetypes.** So for a `.cpp` file, a profile with filetypes `cpp,h` would be considered before a profile with filetypes `cpp,c,txt`.
3. Finally, **select the profiles with the lowest depth** (treating -1 as infinity). Using the previous `main.cpp` example, if there are two profiles in `/home/user/project`, but one of them has depth 2 and the other has depth -1, then the profile with depth 2 would be selected.

<br/>

## 💲 Hooks

Hooks are environment variables.

If you define environment variables in the `{{ hooks }}` section, you can easily modify them *without* opening up the entire profile, by using `zh`. It will open up a window for you to select the hook you want to change, and then prompt you for the new value. Hooks will be accessible in both `{{ setup }}` and the build commands. Here is an example of how you can use them:

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

[[TODO: add image]]

<br/>

### Core Hooks

Some hooks are available by default, and are automatically set every time a build command is run. These are called "core hooks" and can be changed, renamed, or added to in the `setup()` command. The default core hooks are as follows:

|Hook name|Hook value
|-|-|
|`$file`|Always set to the absolute path of the current file.
|`$dir`|Always set to the directory of the current file.
|`$parent`|Always set to the parent directory of the current file.
|`$base`|Always set to the basename of the current file, without the extension.
|`$filename`|Always set to the basename of the current file, including the extension.

<br/>

### Hook Choices

If you declare a hook, but you know in advance that there are only a handful of values it will reasonably have, you can declare another hook that stores the choices for it in an array. This choices hook should have the same name as the original hook but end in `"__c"` (this can be changed). (Note: if on Windows, use the [Powershell array syntax](https://ss64.com/ps/syntax-arrays.html).) Then, when you go to edit the hook, it will display those options in a window for you to easily select. Here is an example:

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

[[TODO: add image]]

<br/>

## 🖋 Naming Builds

You can also give builds a name (alphanumeric characters only, no spaces), like so:

```sh
### {{ zu }}
### {{ name: blur5 }}
./main blur 5 apple.pgm ./output/apple.pgm 
```

This will give the build a custom filename in the builds folder. Doing this has two primary benefits:

 - You can clearly see the name of the build being run, as opposed to something like `/home/.../zuzu/1.sh`, and it might improve readability in the profile editor.
 - zuzu implements caching based on filenames. If you frequently switch between the first build of two different profiles, then zuzu would have to write the build commands to that `1.sh` file each time. However, if you give the two builds different names, then zuzu will only have to load each build in once.

[[TODO: add image]]

<br/>

## 🖥 Display Strategies

Display strategies control the way that build commands are run in Neovim. They are functions that take in the shell command as a string. By default, zuzu uses these three display strategies:

```lua
# require("zuzu.display_strategies")

local M = {}

M.command = function(cmd)
	vim.cmd("!" .. cmd)
end

M.split_right = function(cmd)
	vim.cmd("vertical rightbelow split | terminal " .. cmd)
end

M.split_below = function(cmd)
	vim.cmd("horizontal rightbelow split | terminal " .. cmd)
end

return M
```

To use your own custom display strategies, simply pass them to the `display_strategies` list in the `setup()` function.
