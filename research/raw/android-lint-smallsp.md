# 

<https://googlesamples.github.io/android-custom-lint-rules/checks/SmallSp.md.html>

Text size is too small

Text size is too small

This is a warning.

<table><tbody><tr valign="top"><td data-src-line="6"><dt><a class="target" name="def-id">&nbsp;</a>Id</dt></td><td><dd><p data-src-line="7"><code>SmallSp</code></p></dd></td></tr><tr valign="top"><td data-src-line="8"><dt><a class="target" name="def-summary">&nbsp;</a>Summary</dt></td><td><dd><p data-src-line="9">Text size is too small</p></dd></td></tr><tr valign="top"><td data-src-line="10"><dt><a class="target" name="def-severity">&nbsp;</a>Severity</dt></td><td><dd><p data-src-line="11">Warning</p></dd></td></tr><tr valign="top"><td data-src-line="12"><dt><a class="target" name="def-category">&nbsp;</a>Category</dt></td><td><dd><p data-src-line="13">Usability</p></dd></td></tr><tr valign="top"><td data-src-line="14"><dt><a class="target" name="def-platform">&nbsp;</a>Platform</dt></td><td><dd><p data-src-line="15">Android</p></dd></td></tr><tr valign="top"><td data-src-line="16"><dt><a class="target" name="def-vendor">&nbsp;</a>Vendor</dt></td><td><dd><p data-src-line="17">Android Open Source Project</p></dd></td></tr><tr valign="top"><td data-src-line="18"><dt><a class="target" name="def-feedback">&nbsp;</a>Feedback</dt></td><td><dd><p><a href="https://issuetracker.google.com/issues/new?component=192708" class="url">https://issuetracker.google.com/issues/new?component=192708</a></p></dd></td></tr><tr valign="top"><td data-src-line="20"><dt><a class="target" name="def-since">&nbsp;</a>Since</dt></td><td><dd><p data-src-line="21">Initial</p></dd></td></tr><tr valign="top"><td data-src-line="22"><dt><a class="target" name="def-affects">&nbsp;</a>Affects</dt></td><td><dd><p data-src-line="23">Resource files</p></dd></td></tr><tr valign="top"><td data-src-line="24"><dt><a class="target" name="def-editing">&nbsp;</a>Editing</dt></td><td><dd><p data-src-line="25">This check runs on the fly in the IDE editor</p></dd></td></tr><tr valign="top"><td data-src-line="26"><dt><a class="target" name="def-implementation">&nbsp;</a>Implementation</dt></td><td><dd><p><a href="https://cs.android.com/android-studio/platform/tools/base/+/mirror-goog-studio-main:lint/libs/lint-checks/src/main/java/com/android/tools/lint/checks/PxUsageDetector.java">Source Code</a></p></dd></td></tr><tr valign="top"><td data-src-line="28"><dt><a class="target" name="def-tests">&nbsp;</a>Tests</dt></td><td><dd><p><a href="https://cs.android.com/android-studio/platform/tools/base/+/mirror-goog-studio-main:lint/libs/lint-tests/src/test/java/com/android/tools/lint/checks/PxUsageDetectorTest.java">Source Code</a></p></dd></td></tr><tr valign="top"><td data-src-line="30"><dt><a class="target" name="def-copyrightyear">&nbsp;</a>Copyright Year</dt></td><td><dd><p data-src-line="31">2011</p><p></p></dd></td></tr></tbody></table>

Avoid using sizes smaller than 11sp.

Example

Here is an example of lint warnings produced by this check:

```
res/layout/textsize.xml:33:Warning: Avoid using sizes smaller than 11sp:
10sp [SmallSp]
    android:textSize="10sp" />
    -----------------------
res/layout/textsize.xml:37:Warning: Avoid using sizes smaller than 11sp:
6.5sp [SmallSp]
    android:layout_height="6.5sp" />
    -----------------------------
```

Here is the source file referenced above:

`res/layout/textsize.xml`:

```
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    android:id="@+id/LinearLayout1"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical" >

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="14dp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="14dip" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="14sp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="@android/dimen/mysizedp" />

    <!-- Small -->

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="10sp" />

    <ImageView
        android:layout_width="wrap_content"
        android:layout_height="6.5sp" />

    <!-- No warnings: wrong attribute, size == 0, etc -->

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="0sp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:marginTop="5sp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textSize="11sp" />

</LinearLayout>
```

You can also visit the [source code](https://cs.android.com/android-studio/platform/tools/base/+/mirror-goog-studio-main:lint/libs/lint-tests/src/test/java/com/android/tools/lint/checks/PxUsageDetectorTest.java) for the unit tests for this check to see additional scenarios.

The above example was automatically extracted from the first unit test found for this lint check, `PxUsageDetector.testSpWarnings`. To report a problem with this extracted sample, visit [https://issuetracker.google.com/issues/new?component=192708](https://issuetracker.google.com/issues/new?component=192708).

Suppressing

You can suppress false positives using one of the following mechanisms:

-   Adding the suppression attribute `tools:ignore="SmallSp"` on the problematic XML element (or one of its enclosing elements). You may also need to add the following namespace declaration on the root element in the XML file if it's not already there: `xmlns:tools="http://schemas.android.com/tools"`.
    
    ```
    <?xml version="1.0" encoding="UTF-8"?>
    <resources xmlns:tools="http://schemas.android.com/tools">
        ...
        <style tools:ignore="SmallSp" .../>
      ...
    </resources>
    ```
    
-   Using a special `lint.xml` file in the source tree which turns off the check in that folder and any sub folder. A simple file might look like this:
    
    ```
    <?xml version="1.0" encoding="UTF-8"?>
    <lint>
        <issue id="SmallSp" severity="ignore" />
    </lint>
    ```
    
    Instead of `ignore` you can also change the severity here, for example from `error` to `warning`. You can find additional documentation on how to filter issues by path, regular expression and so on [here](https://googlesamples.github.io/android-custom-lint-rules/usage/lintxml.md.html).
    
-   In Gradle projects, using the DSL syntax to configure lint. For example, you can use something like
    
    ```
    lintOptions {
        disable 'SmallSp'
    }
    ```
    
    In Android projects this should be nested inside an `android { }` block.
    
-   For manual invocations of `lint`, using the `--ignore` flag:
    
    ```
    $ lint --ignore SmallSp ...`
    ```
    
-   Last, but not least, using baselines, as discussed [here](https://googlesamples.github.io/android-custom-lint-rules/usage/baselines.md.html).

_formatted by [Markdeep 1.20](https://casual-effects.com/markdeep)_  

✒
