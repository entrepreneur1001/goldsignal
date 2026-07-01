/// Shared list index math for blending [NativeAdWidget] slots into scroll lists.
library;

const int kNativeAdInterval = 3;

/// Number of native ad slots for [contentCount] content items.
int adListAdCount(int contentCount, {int interval = kNativeAdInterval}) {
  if (contentCount <= 0) return 0;
  if (contentCount < interval) return 1;
  return (contentCount - 1) ~/ interval;
}

/// Total list item count (content + ads).
int adListItemCount(int contentCount, {int interval = kNativeAdInterval}) {
  if (contentCount <= 0) return 0;
  return contentCount + adListAdCount(contentCount, interval: interval);
}

/// Whether [listIndex] in an ad-augmented list should render a native ad.
bool adListIndexIsAd(
  int listIndex,
  int contentCount, {
  int interval = kNativeAdInterval,
}) {
  if (contentCount <= 0) return false;
  if (contentCount < interval) return listIndex == contentCount;
  final block = interval + 1;
  if (listIndex % block != interval) return false;
  final adsBefore = listIndex ~/ block;
  final contentAtAd = adsBefore * interval + interval;
  return contentAtAd < contentCount;
}

/// Maps a list index to the underlying content index.
int adListContentIndex(
  int listIndex,
  int contentCount, {
  int interval = kNativeAdInterval,
}) {
  if (contentCount < interval) return listIndex;
  return listIndex - (listIndex ~/ (interval + 1));
}
