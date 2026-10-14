/// Order-sensitive value equality for the immutable lists held by models.
extension ListValueEquality<T> on List<T> {
  bool hasSameValues(List<T> other) {
    if (identical(this, other)) {
      return true;
    }
    if (length != other.length) {
      return false;
    }
    for (var index = 0; index < length; index++) {
      if (this[index] != other[index]) {
        return false;
      }
    }
    return true;
  }

  int get valuesHash => Object.hashAll(this);
}
