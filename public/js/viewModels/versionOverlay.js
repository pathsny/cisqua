export default function versionOverlay() {
  return {
    open: false,
    loading: false,
    error: null,
    data: null,
    async show() {
      if (this.open) {
        return;
      }
      this.open = true;
      await this.fetchVersion();
    },
    close() {
      this.open = false;
    },
    async fetchVersion() {
      this.loading = true;
      this.error = null;
      try {
        const response = await fetch('/version');
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        this.data = await response.json();
      } catch (err) {
        this.error = 'Failed to load version info.';
      } finally {
        this.loading = false;
      }
    },
    formatRelative(isoTime) {
      if (!isoTime || !window.dateFns) {
        return null;
      }
      try {
        return window.dateFns.formatDistanceToNow(new Date(isoTime), { addSuffix: true });
      } catch (err) {
        return null;
      }
    },
    get commitRelative() {
      return this.formatRelative(this.data?.commit_time);
    },
    copyValue(value, label) {
      if (!value) {
        return;
      }
      this.$copyText(value, { message: `Copied ${label} to Clipboard` });
    },
  };
}
