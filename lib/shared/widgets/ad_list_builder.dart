/// Shared list index math for blending at most one [NativeAdWidget] into scroll lists.
library;

/// Minimum content items required before inserting a single native ad.
const int kNativeAdMinContentBefore = 4;

/// Number of native ad slots for [contentCount] content items (0 or 1).
int adListAdCount(
  int contentCount, {
  int minContentBefore = kNativeAdMinContentBefore,
}) {
  if (contentCount < minContentBefore) return 0;
  return 1;
}

/// Total list item count (content + optional ad).
int adListItemCount(
  int contentCount, {
  int minContentBefore = kNativeAdMinContentBefore,
}) {
  if (contentCount <= 0) return 0;
  return contentCount +
      adListAdCount(contentCount, minContentBefore: minContentBefore);
}

/// Whether [listIndex] should render the single native ad (after [minContentBefore] items).
bool adListIndexIsAd(
  int listIndex,
  int contentCount, {
  int minContentBefore = kNativeAdMinContentBefore,
}) {
  if (contentCount < minContentBefore) return false;
  return listIndex == minContentBefore;
}

/// Maps a list index to the underlying content index.
int adListContentIndex(
  int listIndex,
  int contentCount, {
  int minContentBefore = kNativeAdMinContentBefore,
}) {
  if (contentCount < minContentBefore) return listIndex;
  if (listIndex < minContentBefore) return listIndex;
  return listIndex - 1;
}
