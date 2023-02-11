;;; magit-stats.el --- Generates GIT Repo Statistics Report -*- lexical-binding: t; -*-

;; Author: Rahul M. Juliato
;; Created: Jan 18 2023
;; Version: 0.0.1
;; Keywords: vc, convenience
;; URL: https://github.com/LionyxML/magit-stats
;; Package-Requires: ((emacs "25.1"))
;; SPDX-License-Identifier: GPL-2.0-or-later

;;; Commentary:
;; magit-stats generates reports containing statistics of your GIT Repositories.
;;
;; It uses the ~magit-stats~ npm package CLI Tool for NodeJS.
;;
;; It requires your system to run ~npx~ and have NodeJS
;; (node@latest) installed.  Please first install it if not yet present
;; in your system (see: https://nodejs.org/en/ and
;; https://www.npmjs.com/package/npx)
;;
;; To enable magit-stats, install the package and add it to your load path:
;;     (require 'magit-stats)
;;
;; Call it when inside a file inside a git repository with ~M-x magit-stats RET~
;;

;;; Code:
(require 'shr)

(defgroup magit-stats nil
  "Generates GIT Repo Statistics Report."
  :group 'tools
  :prefix "magit-stats-")

(defcustom magit-stats-backends
  '((?h magit-stats-in-buffer   "HTML report in a new buffer")
    (?o magit-stats-with-viewer "Open HTML report with OS default viewer")
    (?j magit-stats-json-buffer "JSON report data in a new buffer"))
  "List of backends for the `magit-stats' command.
Each entry is of form: (CHAR FN DESCRIPTION)"
  :type 'list)

(defvar magit-stats--output-buffer "*magit-stats-output*")

(defun magit-stats--call (&rest options)
  "Call CLI with command line OPTIONS.
Signal an error if command does not exit with status 0."
  (unless (zerop
           (apply #'call-process
                  `("npx" nil ,magit-stats--output-buffer nil "magit-stats" ,@options)))
    (user-error "%s" (with-current-buffer magit-stats--output-buffer
                       (prog1 (string-trim (buffer-string)) (kill-buffer))))))

(defmacro magit-stats--with-repo (repo &rest body)
  "Execute BODY with `default-directory' bound to REPO."
  (declare (indent 1))
  `(let ((default-directory (file-name-as-directory (expand-file-name ,repo))))
     (message "Loading...")
     ,@body
     (message "Loaded...")))

;;;###autoload
(defun magit-stats-in-buffer (repository)
  "Display HTML report for REPOSITORY in a new buffer."
  (interactive "DRepository: ")
  (magit-stats--with-repo repository
    (magit-stats--call "--html" "--stdout")
    (shr-render-buffer magit-stats--output-buffer)
    (rename-buffer (format "*magit-stats: %s" repository) t)
    (special-mode)
    (kill-buffer magit-stats--output-buffer)))

;;;###autoload
(defun magit-stats-with-viewer (repository)
  "Open HTML report for REPOSITORY with OS default viewer."
  (interactive "DRepository: ")
  (magit-stats--with-repo repository (magit-stats--call)))

;;;###autoload
(defun magit-stats-json-buffer (repository)
  "Display JSON report data for REPOSITORY in a new buffer."
  (interactive "DRepository: ")
  (magit-stats--with-repo repository
    (magit-stats--call "--json" "--stdout")
    (pop-to-buffer magit-stats--output-buffer)
    (js-json-mode)
    (rename-buffer (format "*magit-stats: %s" repository) t)))

(defun magit-stats--read-backend ()
  "Return backend command from `magit-stats-backends'."
  (car (alist-get (read-char-choice
                   (format "magit-stats backend (%s):\n%s"
                           (substitute-command-keys "\\[keyboard-quit] to quit")
                           (mapconcat (lambda (b) (format "%c - %s\n"
                                                          (car b)
                                                          (car (last b))))
                                      magit-stats-backends))
                   (mapcar #'car magit-stats-backends))
                  magit-stats-backends)))

;;;###autoload
(defun magit-stats (repository backend)
  "Generate GIT REPOSITORY statistics via BACKEND.
When called interactively with a prefix arg, prompt for REPOSITORY.
Otherwise default to `default-directory'."
  (interactive (list (if current-prefix-arg
                         (read-directory-name "Directory: ")
                       default-directory)
                     (magit-stats--read-backend)))
  (unless (functionp backend) (user-error "Unknown backend: %s" backend))
  (funcall backend repository))

(provide 'magit-stats)
;;; magit-stats.el ends here
