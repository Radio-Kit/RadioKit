import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() async {
  final process = await Process.start('python3', ['bin/stdio_sleep_test.py'],
    workingDirectory: '/home/sun/Apps/RadioKit/radiokit-app',
    runInShell: true,
  );

  // Listen for stdout
  process.stdout
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .listen((line) => print('STDOUT: $line'));

  // Listen for stderr
  process.stderr
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .listen((line) => print('STDERR: $line'));

  // Wait for the ready signal (4s sleep + overhead)
  print('Waiting for process to be ready...');
  await Future.delayed(Duration(seconds: 6));

  // Send a write command
  print('WRITING TO STDIN...');
  process.stdin.writeln('{"cmd":"write","data":[85,6,0,1,209,241]}');
  await process.stdin.flush();
  print('FLUSH DONE');

  // Wait for response
  await Future.delayed(Duration(seconds: 2));
  process.kill();
  print('DONE');
}
