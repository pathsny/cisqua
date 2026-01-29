const notification = {
  data: null,
  badgeMap: {
    'success': '✔️',
    'warning': '⚠️',
    'error': '❌'
  },
  show(notifData) {
    this.data = {
      ...notifData,
      css_class: notifData.type,
      badge: this.badgeMap[notifData.type],
    }
    setTimeout(() => {
      this.data = null;
    }, 3000);
  }
};

export default notification;
