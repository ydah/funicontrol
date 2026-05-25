window.FunicontrolLineMap = window.FunicontrolLineMap || {
  mount(canvas, payload) {
    const renderer = new LineMapRenderer(canvas);
    renderer.render(payload);
    return renderer;
  },

  update(renderer, payload) {
    if (renderer) renderer.render(payload);
  },

  unmount(renderer) {
    if (renderer) renderer.destroy();
  }
};

class LineMapRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.context = canvas.getContext("2d");
  }

  render(payload) {
    if (!this.context || !payload) return;

    const ctx = this.context;
    const width = this.canvas.width;
    const height = this.canvas.height;
    const stations = payload.stations || [];
    const cars = payload.cars || [];

    ctx.clearRect(0, 0, width, height);
    ctx.lineWidth = 5;
    ctx.lineCap = "round";
    ctx.strokeStyle = "#7d8790";
    ctx.beginPath();
    ctx.moveTo(56, height - 54);
    ctx.lineTo(width - 56, 54);
    ctx.stroke();

    stations.forEach((station) => {
      const point = this.pointFor(station.position, width, height);
      ctx.fillStyle = "#151b1f";
      ctx.strokeStyle = "#4bb6b7";
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
    });
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
    this.context = null;
    this.canvas = null;
  }
}
