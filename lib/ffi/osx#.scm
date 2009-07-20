;;;; "osx ffi types"
;;; Defines c types for the osx ffi.

;;;; Cocoa

(c-define-type id (pointer (struct "objc_object") #f))
(c-define-type NSTimeInterval double)
(c-define-type NSArray "NSArray")
(c-define-type NSArray* (pointer NSArray))
(c-define-type NSSet "NSSet")
(c-define-type NSSet* (pointer NSSet))

;;;; Quartz

(c-define-type CGFloat float)
(c-define-type CGPoint "CGPoint")
(c-define-type CGPoint* (pointer CGPoint))
(c-define-type CGSize "CGSize")
(c-define-type CGSize* (pointer CGSize))
(c-define-type CGRect "CGRect")
(c-define-type CGRect* (pointer CGRect))
