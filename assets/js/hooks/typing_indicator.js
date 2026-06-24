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

    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.el.form?.requestSubmit();
      }
    });
  },

  destroyed() {
    if (this.isTyping) this.pushEvent("stopped_typing", {});
    clearTimeout(this.timeout);
  },
};

export default TypingIndicator;
