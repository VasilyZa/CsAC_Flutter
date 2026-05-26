part of '../../main.dart';

String compactMessage(String text, {int max = 80}) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length <= max) {
    return value;
  }
  return '${value.substring(0, max - 3)}...';
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
