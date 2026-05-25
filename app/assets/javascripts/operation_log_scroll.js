window.FunicontrolOperationLog = window.FunicontrolOperationLog || (() => {
  const positions = new Map();
  const restoring = new WeakSet();

  const keyFor = (key) => String(key || "operation-log");

  const restore = (key, list) => {
    const scrollTop = positions.get(key);
    if (typeof scrollTop !== "number") return;
    if (Math.abs(list.scrollTop - scrollTop) <= 1) return;

    restoring.add(list);
    requestAnimationFrame(() => {
      list.scrollTop = scrollTop;
      requestAnimationFrame(() => restoring.delete(list));
    });
  };

  return {
    bind(key, list) {
      if (!list) return;

      const normalizedKey = keyFor(key);
      if (list.dataset.operationLogScrollKey !== normalizedKey) {
        list.dataset.operationLogScrollKey = normalizedKey;
        list.addEventListener("scroll", () => {
          if (restoring.has(list)) return;
          positions.set(normalizedKey, list.scrollTop || 0);
        }, { passive: true });
      }

      if (!positions.has(normalizedKey)) {
        positions.set(normalizedKey, list.scrollTop || 0);
        return;
      }

      restore(normalizedKey, list);
    }
  };
})();
