window.FunicontrolLineMap = window.FunicontrolLineMap || {
  mount(canvas, payload) {
    const renderer = new LineMapRenderer(canvas);
    renderer.render(payload);
    return renderer;
  },

  update(renderer, payload) {
    if (renderer && !renderer.destroyed) renderer.render(payload);
  },

  unmount(renderer) {
    if (renderer) renderer.destroy();
  }
};

class LineMapRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.context = canvas.getContext("2d");
    this.destroyed = false;
  }

  render(payload) {
    if (this.destroyed || !this.canvas || !payload) return;
    if (!this.context) {
      this.showFallback(true);
      return;
    }
    this.showFallback(false);

    const ctx = this.context;
    const { width, height } = this.resizeForDisplay();
    const stations = payload.stations || [];
    const cars = payload.cars || [];
    const trackSegments = payload.track_segments || [];

    ctx.clearRect(0, 0, width, height);
    ctx.lineWidth = 5;
    ctx.lineCap = "round";
    ctx.strokeStyle = "#7d8790";
    ctx.beginPath();
    ctx.moveTo(56, height - 54);
    ctx.lineTo(width - 56, 54);
    ctx.stroke();

    trackSegments.forEach((segment) => {
      if (segment.kind !== "passing_loop") return;
      const start = this.pointFor(segment.start_position, width, height);
      const end = this.pointFor(segment.end_position, width, height);
      ctx.strokeStyle = "#4bb6b7";
      ctx.lineWidth = 9;
      ctx.globalAlpha = 0.7;
      ctx.beginPath();
      ctx.moveTo(start.x, start.y);
      ctx.lineTo(end.x, end.y);
      ctx.stroke();
      ctx.globalAlpha = 1;
    });

    stations.forEach((station) => {
      const point = this.pointFor(station.position, width, height);
      ctx.fillStyle = "#151b1f";
      ctx.strokeStyle = this.stationColorFor(station.status);
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(point.x, point.y, 8, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#eef2f5";
      ctx.font = "12px system-ui";
      ctx.textAlign = "center";
      ctx.fillText(station.name || "", point.x, point.y + 28);
    });

    cars.forEach((car) => {
      const point = this.pointFor(car.position, width, height);
      const color = this.colorFor(car.status);
      ctx.fillStyle = color;
      ctx.strokeStyle = "#101316";
      ctx.lineWidth = 2;
      ctx.beginPath();
      this.roundRect(ctx, point.x - 28, point.y - 18, 56, 30, 6);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#071018";
      ctx.font = "bold 11px system-ui";
      ctx.textAlign = "center";
      ctx.fillText(car.name || "", point.x, point.y + 3);
      this.drawDirection(ctx, car.direction, point.x, point.y - 27);
    });
  }

  resizeForDisplay() {
    const ratio = window.devicePixelRatio || 1;
    const rect = this.canvas.getBoundingClientRect();
    const width = Math.max(1, Math.round(rect.width * ratio));
    const height = Math.max(1, Math.round(rect.height * ratio));
    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width;
      this.canvas.height = height;
    }
    this.context.setTransform(ratio, 0, 0, ratio, 0, 0);
    return { width: rect.width, height: rect.height };
  }

  pointFor(position, width, height) {
    const clamped = Math.max(0, Math.min(1, Number(position) || 0));
    const x = 56 + (width - 112) * clamped;
    const y = height - 54 - (height - 108) * clamped;
    return { x, y };
  }

  colorFor(status) {
    if (status === "running") return "#4fb06d";
    if (status === "slow") return "#d4a72c";
    if (status === "emergency") return "#e35b5b";
    if (status === "maintenance") return "#9f7aea";
    return "#b8c0c7";
  }

  stationColorFor(status) {
    if (status === "alert") return "#e35b5b";
    if (status === "crowded") return "#d4a72c";
    if (status === "closed") return "#7d8790";
    return "#4bb6b7";
  }

  drawDirection(ctx, direction, x, y) {
    if (!direction || direction === "idle") return;

    ctx.fillStyle = "#eef2f5";
    ctx.beginPath();
    if (direction === "down") {
      ctx.moveTo(x, y + 8);
      ctx.lineTo(x - 6, y - 4);
      ctx.lineTo(x + 6, y - 4);
    } else {
      ctx.moveTo(x, y - 8);
      ctx.lineTo(x - 6, y + 4);
      ctx.lineTo(x + 6, y + 4);
    }
    ctx.closePath();
    ctx.fill();
  }

  roundRect(ctx, x, y, width, height, radius) {
    if (typeof ctx.roundRect === "function") {
      ctx.roundRect(x, y, width, height, radius);
      return;
    }

    const r = Math.min(radius, width / 2, height / 2);
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + r);
    ctx.lineTo(x + width, y + height - r);
    ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    ctx.lineTo(x + r, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
  }

  destroy() {
    this.destroyed = true;
    this.context = null;
    this.canvas = null;
  }

  showFallback(visible) {
    const fallback = this.canvas?.parentElement?.querySelector(".canvas-fallback");
    if (fallback) fallback.hidden = !visible;
  }
}
