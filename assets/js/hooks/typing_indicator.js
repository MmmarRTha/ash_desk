const TypingIndicator = {
  mounted() {
    this.timeout = null;
    this.isTyping = false;

    this.el.addEventListener("input", () => {
      if (!this.isTyping) {
        this.isTyping = true;
        this.pushEvent("typing_start", {});
      }
      clearTimeout(this.timeout);
      this.timeout = setTimeout(() => {
        this.isTyping = false;
        this.pushEvent("stopped_typing", {});
      }, 2000);
    });
  },

  destroyed() {
    if (this.isTyping) this.pushEvent("stopped_typing", {});
    clearTimeout(this.timeout);
  },
};

export default TypingIndicator;
