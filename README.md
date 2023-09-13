<p align="center">
  <a href="https://github.com/TypedDevs/bashunit/actions/workflows/tests.yml">
    <img src="https://github.com/TypedDevs/bashunit/actions/workflows/tests.yml/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/TypedDevs/bashunit/actions/workflows/static_analysis.yml">
    <img src="https://github.com/TypedDevs/bashunit/actions/workflows/static_analysis.yml/badge.svg" alt="Static analysis">
  </a>
  <a href="https://github.com/TypedDevs/bashunit/actions/workflows/contributors.yml">
    <img src="https://github.com/TypedDevs/bashunit/actions/workflows/contributors.yml/badge.svg" alt="Contributors">
  </a>
  <a href="https://github.com/TypedDevs/bashunit/actions/workflows/deploy-docs.yml">
    <img src="https://github.com/TypedDevs/bashunit/actions/workflows/deploy-docs.yml/badge.svg" alt="Docs deployment">
  </a>
  <a href="https://github.com/TypedDevs/bashunit/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT Software License">
  </a>
</p>
<br>
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo_name_dark.svg">
    <img alt="bashunit" src="docs/assets/logo_name.svg" width="400">
  </picture>
</p>

<h1 align="center">Minimalistic Bash Testing</h1>

## Usage

`./bashunit <test_script>`

#### Example: Defining your own tests

```bash
# example/logic.sh

echo "expected $1"
```

```bash
# example/logic_test.sh

SCRIPT="./logic.sh"

function test_your_logic() {
  assertEquals "expected 123" "$($SCRIPT "123")"
}
```

Check out the [example](example/README.md) directory for more.

## Installation

Although there's no Bash script dependency manager like `npm` for JavaScript, `Maven` for Java, `pip` for Python, or `composer` for PHP; you can install this project in your repository according to your preferences. Here, I provide a Git submodule option that will work for you.

### Git submodule

You can use Git submodules to include external Git repositories within your project. This approach works well for including Bash scripts or other resources from remote repositories.

```bash
git submodule add git@github.com:TypedDevs/bashunit.git tools/bashunit
```

#### Versioning and updates

To update a git-submodule:
1. keep the git-submodule under your git (committed)
2. go inside the git-submodule and:
   1. `git submodule update --remote` (preferred)
   2. or pull `main`
   3. or checkout a concrete release tag


## Contribute

You are welcome to contribute reporting issues, sharing ideas,
or [with your Pull Requests](.github/CONTRIBUTING.md).

## Contributors

<table>
<tr>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href=https://github.com/Chemaclass>
            <img src=https://avatars.githubusercontent.com/u/5256287?v=4 width="100;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Jose Maria Valera Reales/>
            <br />
            <sub style="font-size:14px"><b>Jose Maria Valera Reales</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href=https://github.com/khru>
            <img src=https://avatars.githubusercontent.com/u/6353105?v=4 width="100;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Emmanuel Valverde Ramos/>
            <br />
            <sub style="font-size:14px"><b>Emmanuel Valverde Ramos</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href=https://github.com/Tito-Kati>
            <img src=https://avatars.githubusercontent.com/u/13595197?v=4 width="100;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Antonio Gonzalez/>
            <br />
            <sub style="font-size:14px"><b>Antonio Gonzalez</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href=https://github.com/CosmeValera>
            <img src=https://avatars.githubusercontent.com/u/80126839?v=4 width="100;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Cosme Valera Reales/>
            <br />
            <sub style="font-size:14px"><b>Cosme Valera Reales</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href=https://github.com/JesusValera>
            <img src=https://avatars.githubusercontent.com/u/6381924?v=4 width="100;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Jesus Valera Reales/>
            <br />
            <sub style="font-size:14px"><b>Jesus Valera Reales</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href=https://github.com/fabriziofs>
            <img src=https://avatars.githubusercontent.com/u/62360034?v=4 width="100;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Fabrizio Fasanando/>
            <br />
            <sub style="font-size:14px"><b>Fabrizio Fasanando</b></sub>
        </a>
    </td>
</tr>
</table>
