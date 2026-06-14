import re

fp = 'lib/screens/designer/designer_screen.dart'

with open(fp, 'r') as f:
    content = f.read()

original = content

# ── Fix 1: Add tokens variable in _editProjectName ──
old = '    final controller = TextEditingController(text: _state.modelName);\n    final newName = await showDialog<String>(' 
new_text = '    final tokens = RKTheme.of(context);\n    final controller = TextEditingController(text: _state.modelName);\n    final newName = await showDialog<String>('
content = content.replace(old, new_text)

# ── Fix 2: Add tokens variable in _handleBack ──
old = '    final router = GoRouter.of(context);\n    final navigator = Navigator.of(context);\n    final canPop = context.canPop();'
new_text = '    final tokens = RKTheme.of(context);\n    final router = GoRouter.of(context);\n    final navigator = Navigator.of(context);\n    final canPop = context.canPop();'
content = content.replace(old, new_text)

# ── Fix 3: _buildCodeEditor indicatorBuilder — use editorTokens ──
old = '''        indicatorBuilder: (context, editingController,
          chunkController, notifier) {
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: const TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.33),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            Container(width: 1, color: tokens.base200),
            const SizedBox(width: 4),'''
new_text = '''        indicatorBuilder: (context, editingController,
          chunkController, notifier) {
        final editorTokens = RKTheme.of(context);
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: TextStyle(
                color: editorTokens.onSurface.withValues(alpha: 0.33),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            Container(width: 1, color: editorTokens.base200),
            const SizedBox(width: 4),'''
content = content.replace(old, new_text)

# ── Fix 4: _buildSaveAsButton — context.tokens → tokens ──
content = content.replace(
    "color: context.tokens.onSurface.withValues(alpha: 0.54), size: 14",
    "color: tokens.onSurface.withValues(alpha: 0.54), size: 14"
)
content = content.replace(
    "color: context.tokens.onSurface.withValues(alpha: 0.54),\n                fontSize: 11,\n                fontFamily: 'monospace',\n                fontWeight: FontWeight.bold,",
    "color: tokens.onSurface.withValues(alpha: 0.54),\n                fontSize: 11,\n                fontFamily: 'monospace',\n                fontWeight: FontWeight.bold,"
)

# ── Fix 5: Remove const violations ──
def remove_const_from_line_if_tokens(line):
    if 'context.tokens' in line or 'tokens.' in line or 'editorTokens' in line or 'RKTheme' in line:
        # Remove const before widget constructors
        pattern = r'\bconst\s+(?=(TextStyle|Text|SizedBox|Icon|Container|Padding|Row|Column|Center|FilledButton|OutlinedButton|ElevatedButton|Divider|Border|BorderSide|SafeArea|ClipRRect|Stack|Positioned|Expanded|Flexible|Wrap|InkWell|GestureDetector|Material|AnimatedContainer|DefaultTabController|TabBar|Tab|Scaffold|AppBar|Card|ListTile|CircleAvatar|Align|Transform|Opacity|Theme|MediaQuery|ValueListenableBuilder|FittedBox|ConstrainedBox|LayoutBuilder|AspectRatio|IntrinsicHeight|IntrinsicWidth|Spacer|Flex|FractionallySizedBox|SizedOverflowBox|Offstage|Tooltip|Chip|InputChip|FilterChip|ChoiceChip|ActionChip|IconButton|TextButton|SnackBar|AlertDialog|SimpleDialog|Dialog|ButtonBar|ToggleButtons|RotatedBox|DecoratedBox|RichText|TextSpan|Ink|BackdropFilter|ShaderMask|Hero|Semantics|ExcludeSemantics|Builder|Actions|Shortcuts|Focus|FocusScope|AnnotatedRegion|Banner|Placeholder|Title|Caption|Headline|Body|Label|InheritedWidget|InheritedTheme|StreamBuilder|FutureBuilder|OrientationBuilder|NotificationListener|PrimaryScrollController|Scrollbar|ScrollConfiguration|Scrollable|AnimatedCrossFade|AnimatedSwitcher|AnimatedList|AnimatedGrid|SelectableText|DefaultTextStyle|AnimatedBuilder|TweenAnimationBuilder|AnimatedOpacity|AnimatedPadding|AnimatedAlign|BoxDecoration)\()'
        line = re.sub(pattern, '', line)
    return line

lines = content.split('\n')
lines = [remove_const_from_line_if_tokens(l) for l in lines]
content = '\n'.join(lines)

# ── Fix 6: Replace context.tokens with tokens in code viewer ──
content = content.replace('context.tokens.onPrimary', 'tokens.onPrimary')
content = content.replace('context.tokens.onSurface', 'tokens.onSurface')

if content != original:
    with open(fp, 'w') as f:
        f.write(content)
    print(f'{fp}: Fixed ~{(len(content) - len(original)) // 5} issues')
else:
    print(f'{fp}: No changes needed')

print('Done!')
