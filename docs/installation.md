# Installation

Although there's no Bash script dependency manager like npm for JavaScript, Maven for Java, pip for Python, or composer for PHP;
you can add **bashunit** as a dependency in your repository according to your preferences.

Here, we provide different options that you can use to install **bashunit** in your application.

### Using install.sh

There is a tool that will generate an executable with the whole library in a single file:

```bash
curl -s https://bashunit.typeddevs.com/install.sh | bash
```

This will create a file inside a lib folder, such as `lib/bashunit`.

#### Define custom tag and folder

The installation script can receive two optional arguments:

```bash
curl -s https://bashunit.typeddevs.com/install.sh | bash -s [dir] [version]
```
- `[dir]`: the destiny directory to save the executable bashunit; `lib` by default
- `[version]`: the [release](https://github.com/TypedDevs/bashunit/releases) to download, for instance `{{ pkg.version }}`; `latest` by default

> Committing (or not) this file to your project it's up to you. In the end, it is a dev dependency.
>
### On a Git project using Git submodules

You can use Git submodules to include external Git repositories, like **bashunit**, within your Git project.
This approach works well for including Bash scripts or other resources from remote repositories.

For this, you'll simply need to run the following script at the root of your Git project.
The final `bashunit` is the folder where you want to install **bashunit**.
For instance, if you prefer to have your dependencies inside the `deps` folder, just replace it with `deps/bashunit`.
```bash
git submodule add -b latest git@github.com:TypedDevs/bashunit.git bashunit
```

### Updating

After adding **bashunit** as a submodule, you can update it by simply running the following command from the submodule root folder.
```bash
cd bashunit
git submodule update --remote
```

### Using a specific version

To use a specific version of **bashunit**, simply run the following command from the submodule root folder, replacing `[version]` with the desired version, for example `{{ pkg.version }}`.
```bash
cd bashunit
git checkout [version]
```

If you want to revert to the latest version, just run the following commands from the submodule root folder.
```bash
cd bashunit
git checkout latest
git submodule update --remote
```

<script setup>
import pkg from '../package.json'
</script>
