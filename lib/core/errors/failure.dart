abstract class Failure {
  final String message;
  const Failure(this.message);
}

class AudioFailure extends Failure {
  const AudioFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
