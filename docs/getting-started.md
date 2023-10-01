# Getting Started

**bashunit** is a dedicated testing tool crafted specifically for Bash scripts. It empowers you with tests on your Bash codebase, ensuring that your scripts operate reliably and as intended.

With an intuitive API and documentation, it streamlines the process for developers to implement and manage tests. This is beneficial regardless of the project's size or intricacy in Bash.

Thanks to **bashunit**, verifying and validating your Bash code has never been so easy and efficient.

## Installation

Although there's no Bash script dependency manager like npm for JavaScript, Maven for Java, pip for Python, or composer for PHP;
you can add **bashunit** as a dependency in your repository according to your preferences.

Here, we provide different options that you can use to install **bashunit** in your application.

### Using install.sh

There is a tool that will generate an executable with the whole library in a single file:

```bash
curl -s https://raw.githubusercontent.com/TypedDevs/bashunit/main/install.sh | bash
```

This will create a file inside a lib folder, such as `lib/bashunit`.

#### Define custom tag and folder

The installation script can receive two optional arguments:

```bash
curl -s https://raw.githubusercontent.com/TypedDevs/bashunit/main/install.sh\
  | bash -s 0.7.0 bin
```
- `$1`: the [released TAG](https://github.com/TypedDevs/bashunit/releases) to download, or main by default
- `$2`: the destiny folder to save the executable bashunit, or lib by default

In this example, it will download the `0.7.0` inside `bin/bashunit`

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

To use a specific version of **bashunit**, simply run the following command from the submodule root folder, replacing `[version]` with the desired version, for example `0.6.0`.
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

## Usage

Once **bashunit** is installed, you're ready to get started.

1.  First, create a folder to place your tests:
    ```bash
    mkdir tests
    ```

2.  Next, create your first test file named `example_test.sh` within this folder with the following content:
    ```bash
    #!/bin/bash

    function test_bashunit_is_working() {
      assert_equals "bashunit is working" "bashunit is working"
    }
    ```
    ::: tip
    You can add as many test functions to a test file as you want.
    Just ensure they're prefixed with `test`; otherwise, **bashunit** won't execute them.
    :::

3.  Finally, run the **bashunit** executable, passing your test file as argument.
    If you use wildcards, **bashunit** will run any tests it finds.

    You can copy and execute the following command from the root of your project if you installed **bashunit** as a Git submodule:
    ```bash
    bashunit/bashunit tests/example_test.sh
    ```

4.  If everything works correctly, you should see an output similar to the following:
    ```bash
    Running tests/example_test.sh
    ✓ Passed: Bashunit is working

    Tests:      1 passed, 1 total
    Assertions: 1 passed, 1 total
    All tests passed
    Time taken: 100 ms
    ```

5.  Now you can start testing the functionalities of your own Bash scripts.

## Next steps

Dive deeper into the documentation to discover the various assertions and functionalities available.

## Support

If you encounter any issues, require clarification, or wish to suggest improvements, the primary avenue for support is through [our GitHub repository's issue tracking system](https://github.com/TypedDevs/bashunit/issues).
How to Get Support:

1.  **Navigate to our Issues Page**:
    Visit the issues section of our repository.
2.  **Search for Existing Issues**:
    Before creating a new issue, please search to ensure that your concern hasn't been addressed already.
3.  **Create a New Issue**:
    If your concern isn't previously reported, click on the 'New issue' button.
    Please provide as much detail as possible, including error messages, steps to reproduce, and expected outcomes.
4.  **Engage Constructively**:
    When interacting on issues, please be respectful and constructive, understanding that the community aims to help and enhance the tool collaboratively.

We value our community's feedback and aim to address all concerns in a timely and effective manner.
Your active participation and constructive feedback play a pivotal role in the continuous improvement of **bashunit**.
