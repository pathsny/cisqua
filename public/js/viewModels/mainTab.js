const mainTab = {
  activeTab: window.location.hash ? window.location.hash.substring(1) : 'scans',
  isScrolled: { scans: false, library: false },
  setActiveTab(tabName) {
    this.activeTab = tabName;
    history.pushState({ tab: tabName }, '', `#${tabName}`);
  },
  isTabActive(tabName) {
    return this.activeTab === tabName;
  },
  scrollToTop(elem) {
    elem.scrollTo({ top: 0, behavior: 'smooth' });
  }
};

export default mainTab;
