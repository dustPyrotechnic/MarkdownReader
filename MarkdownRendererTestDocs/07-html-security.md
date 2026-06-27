# HTML And Security

如果你的渲染器不支持 HTML，以下内容应安全地原样显示或被转义。如果支持 HTML，也应避免脚本执行、事件执行和样式污染。

Inline HTML: <span class="test-span">span text</span>

Block HTML:

<div class="notice">
  <strong>HTML strong text</strong>
</div>

Potential script:

<script>
alert("This script must not execute.");
</script>

Event handler:

<img src="x" onerror="alert('onerror must not execute')" alt="bad image">

JavaScript URL:

[javascript link](javascript:alert("must not execute"))

Data URL:

[data url](data:text/html,<script>alert(1)</script>)

Style injection:

<style>
body { display: none !important; }
</style>

Iframe:

<iframe src="https://example.com"></iframe>

HTML comments:

<!-- This comment should not break rendering. -->

Unclosed HTML:

<div>
This div is intentionally not closed.

The rest of the document should not inherit unexpected styles or disappear.
