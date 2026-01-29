import { invariant } from '../utils/utils.js';

function scanShow() {
  const noHover = {
    aid: null,
    scanId: null,
    anchorId: 'scans',
    anime: null,
  };
  return {
    init() {
      this.hover = noHover;
      this.nextShow = null;
      this.clearTimeoutHandle = null;
      this.showTimeoutHandle = null;
      this.expandedHeaders = new Set();
    },
    cancelShow() {
      clearTimeout(this.showTimeoutHandle);
      this.showTimeoutHandle = null;
      this.nextShow = null;
    },
    cancelClear() {
      clearTimeout(this.clearTimeoutHandle);
      this.clearTimeoutHandle = null;
    },
    setShow(show) {
      if (!show) {
        this.hover = noHover;
      } else {
        this.hover = {
          ...show,
          anchorId: `${show.scanId}-${show.aid}-img`,
          get anime() {
            return Alpine.store('library').animeDetails.get(this.aid);
          },
        };
      }
    },
    setHoverAnime(scanId, aid) {
      if (this.hover.scanId === scanId && this.hover.aid === aid) {
        // cancel any timers and next steps if we're back on the same show.
        this.cancelClear();
        this.cancelShow();
        return
      }
      if (this.nextShow?.scanId === scanId && this.nextShow?.aid === aid) {
        // this is already the plan
        return;
      }
      // we allow a clear timer to run if there is one.
      this.cancelShow();

      this.nextShow = { aid, scanId };
      this.showTimeoutHandle = setTimeout(
        () => {
          this.showTimeoutHandle = null;
          this.setShow(this.nextShow);
          this.nextShow = null;
        },
        500
      );
    },
    clearHoverAnime() {
      if (this.showTimeoutHandle) {
        // never pop up a card we were about to if asked to clear
        this.cancelShow();
      }
      if (this.clearTimeoutHandle) {
        return;
      }
      if (!this.hover.aid) {
        return
      }
      this.clearTimeoutHandle = setTimeout(() => {
        this.clearTimeoutHandle = null;
        this.setShow(null);
      }, 200);
    },
    onEnterHoverCard() {
      invariant(this.hover.aid, 'must be true if we enter the hover card');
      this.setHoverAnime(this.hover.scanId, this.hover.aid);
    },
    onLeaveHoverCard() {
      this.clearHoverAnime();
    },
    toggleScanHeaderDetails(scanId) {
      if (this.expandedHeaders.has(scanId)) {
        this.expandedHeaders.delete(scanId);
      } else {
        this.expandedHeaders.add(scanId);
      }
    },
    scanHeaderExpanded(scanId) {
      return this.expandedHeaders.has(scanId);
    },
  }
}

export default scanShow;
