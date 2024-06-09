<img src="./icon.png" width="96" />

# alfred-workflow-configurator

### What

A little Zsh script to keep your Workflows enabled or disabled programmatically.

### Why

When updating Workflows, Alfred's current behavior is to re-enable a Workflow, _even if it was Disabled prior to the update_. This might make sense for most people, but it wasn't what I wanted. I wrote this to keep my Workflows set the way I wanted them.

### How

There is 1 dependency: [`jq`](https://jqlang.github.io/jq/) which is easily satisfied by `brew install jq` if you don't have it.

Other than that, just download the release, unzip it and place the `alfred-workflow-configurator.sh` script in your `$PATH` somewhere.

When run with no arguments (or with `-h/--help`) the helptext will be displayed.

The configuration is stored in an .ini-style file in the same folder as your Alfred preferences (will be automatically determined by reading Alfred's settings file).

#### Commandline Arguments

|arg|function|
|---|---|
|`--init`|create (or recreate) the configuration file that is used to control which Workflows are disabled|
|`--table`|output information of each Workflow: Name, current state, and bundle ID|
|`--check`|check your Workflows and adjust them if needed so they match your saved config|
|`--cfg`|open the configuration file for editing|

### Discussion

https://www.alfredforum.com/topic/21940-not-quite-a-bug-updating-a-workflow-should-not-automatically-enable-it-if-disabled/
