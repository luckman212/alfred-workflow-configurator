<img src="./icon.png" width="96" />

# alfred-workflow-configurator

### What

A little Zsh script to keep your Workflows enabled or disabled programmatically.

### Why

When updating Workflows, Alfred's current behavior is to re-enable a Workflow, even if it was Disabled prior to the update. This might make sense for most people, but it wasn't what I wanted. So I wrote this to keep my Workflows set the way I wanted them. 

### How

There is 1 dependency: [`jq`](https://jqlang.github.io/jq/) which is easily satisfied by `brew install jq` if you don't have it.

Other than that, just place the script in your `$PATH` and run it. When run with no parameters (or with `-h/--help`) the helptext will be displayed.

### Discussion

https://www.alfredforum.com/topic/21940-not-quite-a-bug-updating-a-workflow-should-not-automatically-enable-it-if-disabled/
