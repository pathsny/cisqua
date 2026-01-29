function searchLibrary() {
  return {
    searchInput: '',
    searchTerm: null,
    search() {
      if (this.searchInput.length > 2) {
        this.searchTerm = this.searchInput;
      } else {
        this.searchTerm = null;
      }
    }
  }
}

export default searchLibrary;
