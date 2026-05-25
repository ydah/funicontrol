window.FunicontrolUpload = window.FunicontrolUpload || {
  submit(method, url, fields, fileField, fileGlobalKey) {
    const formData = new FormData();
    Object.entries(fields || {}).forEach(([key, value]) => {
      if (value !== null && value !== undefined) formData.append(key, String(value));
    });

    const file = fileGlobalKey ? window[fileGlobalKey] : null;
    if (file && fileField) formData.append(fileField, file);

    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content");
    const headers = token ? { "X-CSRF-Token": token } : {};

    return fetch(url, {
      method,
      body: formData,
      credentials: "include",
      headers
    }).then(async (response) => {
      const data = await response.json();
      return { ok: response.ok, status: response.status, data };
    });
  },

  submitWithEvent(method, url, fields, fileField, fileGlobalKey, eventName) {
    return this.submit(method, url, fields, fileField, fileGlobalKey)
      .then((result) => {
        window.dispatchEvent(new CustomEvent(eventName, { detail: result }));
        return result;
      })
      .catch((error) => {
        const result = {
          ok: false,
          status: 0,
          data: { errors: { base: [String(error)] } }
        };
        window.dispatchEvent(new CustomEvent(eventName, { detail: result }));
        return result;
      });
  },

  submitSerialized(method, url, fields, fileField, fileGlobalKey) {
    return this.submit(method, url, fields, fileField, fileGlobalKey)
      .catch((error) => ({
        ok: false,
        status: 0,
        data: { errors: { base: [String(error)] } }
      }))
      .then((result) => JSON.stringify(result));
  }
};
