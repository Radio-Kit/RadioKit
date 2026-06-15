import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() async {
  final process = await Process.start('python3', ['bin/stdio_test.py'],
    workingDirectory: '/home/sun/Apps/RadioKit/radiokit-app',
    runInShell: true,
  );

  // Listen for stdout
  process.stdout
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .listen((line) => print('STDOUT: $line'));

  // Wait 2 seconds for the process to start
  await Future.delayed(Duration(seconds: 2));

  // Send a write command
  print('WRITING TO STDIN...');
  process.stdin.writeln('{"cmd":"write","data":[85,6,0,1,209,241]}');
  await process.stdin.flush();
  print('FLUSH DONE');

  // Wait for response
  await Future.delayed(Duration(seconds: 2));

  // Try writing again without newline
  print('WRITING WITH WRITE...');
  process.stdin.write('{"cmd":"write","data":[85,6,0,1,209,241]}\n');
  await process.stdin.flush();
  print('FLUSH2 DONE');

  await Future.delayed(Duration(seconds: 2));
  process.kill();
  print('DONE');
}
