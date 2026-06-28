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

    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.el.form?.requestSubmit();
      }
    });
  },

  destroyed() {
    clearTimeout(this.timeout);
    this.pushEvent("stopped_typing", {});
  },
};

export default TypingIndicator;
