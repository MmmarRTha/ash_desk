const TypingIndicator = {
  mounted() {
    this.timeout = null;

    this.el.addEventListener("input", () => {
      this.pushEvent("typing_start", {});
      clearTimeout(this.timeout);
      this.timeout = setTimeout(() => {
        this.pushEvent("stopped_typing", {});
      }, 5000);
    });
  },

  destroyed() {
    clearTimeout(this.timeout);
    this.pushEvent("stopped_typing", {});
  },
};

export default TypingIndicator;
