// Timora Web Browser APIs Bridge
// Provides safe, cross-browser Notification and SpeechSynthesis APIs for Flutter Web

(function () {
  'use strict';

  window.TimoraWeb = {
    // ── Notifications ───────────────────────────────────────────────────────
    isNotificationSupported: function () {
      return typeof window !== 'undefined' && 'Notification' in window;
    },

    getNotificationPermission: function () {
      if (!this.isNotificationSupported()) {
        return 'denied';
      }
      return Notification.permission; // 'granted', 'denied', or 'default'
    },

    requestNotificationPermission: function () {
      if (!this.isNotificationSupported()) {
        return Promise.resolve('denied');
      }
      try {
        return Notification.requestPermission();
      } catch (e) {
        return Promise.resolve('denied');
      }
    },

    showNotification: function (title, body, tag, icon) {
      if (!this.isNotificationSupported()) {
        return false;
      }
      if (Notification.permission !== 'granted') {
        return false;
      }
      try {
        var options = {
          body: body || '',
          icon: icon || 'favicon.png',
          badge: 'favicon.png',
          tag: tag || ('timora_' + Date.now()),
          renotify: true,
        };
        new Notification(title || 'Timora', options);
        return true;
      } catch (e) {
        console.warn('[TimoraWeb] Error showing notification:', e);
        return false;
      }
    },

    // ── Speech Synthesis ────────────────────────────────────────────────────
    isSpeechSupported: function () {
      return typeof window !== 'undefined' && 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window;
    },

    speak: function (text, rate, pitch, volume) {
      if (!this.isSpeechSupported() || !text) {
        return false;
      }
      try {
        // Cancel any queued speech before speaking new message
        window.speechSynthesis.cancel();

        var utterance = new SpeechSynthesisUtterance(text);
        utterance.rate = typeof rate === 'number' ? rate : 1.0;
        utterance.pitch = typeof pitch === 'number' ? pitch : 1.0;
        utterance.volume = typeof volume === 'number' ? volume : 1.0;

        // Try to pick an English voice if available
        var voices = window.speechSynthesis.getVoices();
        if (voices && voices.length > 0) {
          var enVoice = voices.find(function (v) {
            return v.lang && v.lang.indexOf('en') === 0;
          });
          if (enVoice) {
            utterance.voice = enVoice;
          }
        }

        window.speechSynthesis.speak(utterance);
        return true;
      } catch (e) {
        console.warn('[TimoraWeb] Speech synthesis error:', e);
        return false;
      }
    },

    stopSpeech: function () {
      if (this.isSpeechSupported()) {
        try {
          window.speechSynthesis.cancel();
        } catch (e) {}
      }
    },

    // ── File Download ───────────────────────────────────────────────────────
    downloadFile: function (filename, content, mimeType) {
      try {
        var blob = new Blob([content], { type: mimeType || 'application/json' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = filename || 'download.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        return true;
      } catch (e) {
        console.warn('[TimoraWeb] Download error:', e);
        return false;
      }
    }
  };

  console.log('[TimoraWeb] Timora Web Bridge initialized.');
})();
