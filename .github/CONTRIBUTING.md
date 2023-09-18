# Contributing to bashunit

## We have a Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## Any contributions you make will be under the MIT License

When you submit code changes, your submissions are understood to be under the same [MIT](https://github.com/TypedDevs/bashunit/blob/main/LICENSE) that covers the project. By contributing to this project, you agree that your contributions will be licensed under its MIT.

## Write bug reports with detail, background, and sample code

In your bug report, please provide the following:

* A quick summary and/or background
* Steps to reproduce
    * Be specific!
    * Give sample code if you can.
* What you expected would happen
* What actually happens
* Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

Please post code and output as text ([using proper markup](https://guides.github.com/features/mastering-markdown/)). Additional screenshots to help contextualize behavior are ok.

## Workflow for Pull Requests

1. Fork/clone the repository.
2. Create your branch from `main` if you plan to implement new functionality or change existing code significantly.
3. Implement your change and add tests for it.
4. Ensure the test suite passes.
5. Ensure the code complies with our coding guidelines (see below).
6. Send that pull request!

Please make sure you have [set up your username and email address](https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup) for use with Git. Strings such as `silly nick name <root@localhost>` looks bad in the commit history of a project.

## Specific set up for documentation application

Our documentation is build with [VitePress](https://vitepress.dev/), for set up a local environment to contribute follow these steps:
1. You'll need `node`(_we recommend using [nvm](https://github.com/nvm-sh/nvm)_) and `yarn` for set up the environment.
   * Using `nvm` you can execute `nvm use`(reads _.nvmrc_ file) in the project root directory and follow the instructions to use the correct `node` version.
   * To install `yarn` you can use `npm i -g yarn`.
2. Install dependencies with `yarn install`.
3. Run local development server with `yarn docs:dev`.
4. Implement your changes.
5. Before submitting your Pull Request run `docs:build` to ensure everything works.

## Change the configuration
To change the configuration for the project we use the `.env` file if you would like to know what variables should be there use the following command:
```bash
cp .env.example .env
```

## Testing

Run tests from the library:
```bash
# using make
make test

# using bashunit itself
./bashunit tests/**/*_test.sh
```

Run the test with a watcher for development:
this will require to have installed [fswatcher](https://github.com/emcrisostomo/fswatch)
```bash
# you have to install `watch` for your OS
make test/watch
```

## Coding Guidelines

### Shellcheck

To contribute to this repository you must have [ShellCheck](https://github.com/koalaman/shellcheck) installed on your local machine or IDE, since it is the static code analyzer that is being used in continuous integration pipelines.

Installation: https://github.com/koalaman/shellcheck#installing

#### Example of usage

```bash
# using make
make sa

# using ShellCheck itself
shellcheck ./**/**/*.sh -C
```

### Editorconfig checker

To contribute to this repository, consider installing [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker) to check all project files regarding the `.editorconfig` to ensure we all fulfill the standard.

Installation: https://github.com/editorconfig-checker/editorconfig-checker#installation

To run it, use the following command:
```bash
# using make
make lint

# using editorconfig-checker itself
ec -config .editorconfig
```

This command will be executed on the CI to ensure the project's quality standards.

#### We recommend

To install the pre-commit of the project with the following command:

**Please note that you will need to have ShellCheck and editorconfig-checker installed on your computer.**
See above how to install in your local.

```bash
make pre_commit/install
```

[Shell Guide](https://google.github.io/styleguide/shellguide.html#s7.2-variable-names) by Google Conventions.

### Documentation
For us the documentation its really important, we are a small group and we want to mantain this project for long, to do that we will need your help

## ADR
If you want to change something related to the architecture or apply a change that it's a decision on how the library works please use [ADR](https://adr.github.io/) otherwise we will request you to do so on the PR.
* [ADR templates](https://github.com/joelparkerhenderson/architecture-decision-record)
