/// Returns 1/2/4 columns based on screen width.
int columnCount(double width) {
  if (width > 1200) return 4;
  if (width > 600) return 2;
  return 1;
}
