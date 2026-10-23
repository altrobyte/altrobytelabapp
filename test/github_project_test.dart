import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/local_tools.dart';

void main() {
  test('a GitHub link gives the owner, the repo and the branch when there is one', () {
    expect(githubRepoOf('https://github.com/altrobyte/pwm-demo'), (owner: 'altrobyte', repo: 'pwm-demo', branch: null));
    expect(githubRepoOf('https://github.com/altrobyte/pwm-demo.git'), (owner: 'altrobyte', repo: 'pwm-demo', branch: null));
    expect(githubRepoOf('https://github.com/a-b/c_d/tree/dev'), (owner: 'a-b', repo: 'c_d', branch: 'dev'));
    expect(githubRepoOf('https://github.com/a/b/tree/main/src?x=1'), (owner: 'a', repo: 'b', branch: 'main'));
    expect(githubRepoOf('https://gitlab.com/a/b'), isNull);
  });
}
