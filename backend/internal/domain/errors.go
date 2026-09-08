// Package domain is the business core of AAM. It holds the entities and the
// port interfaces (repositories, authenticators, device sync). It must not
// import the web framework, the database driver, or anything hardware-specific
// — those live in internal/adapter and talk to this package through the
// interfaces declared here.
package domain

import "fmt"

// DomainError is a business rule violation that the HTTP adapter maps to a
// response of the form {"detail": "<message>"} with the given status code.
// It mirrors the *Error exception classes of the previous Python backend
// (AltaAlumnoError, CourseError, RegistrarAsistenciaError, ...).
type DomainError struct {
	Message    string
	StatusCode int
}

func (e *DomainError) Error() string { return e.Message }

// NewDomainError builds a DomainError. status defaults to 400 when zero.
func NewDomainError(message string, status int) *DomainError {
	if status == 0 {
		status = 400
	}
	return &DomainError{Message: message, StatusCode: status}
}

// Errorf is a formatting helper for the common 400 case.
func Errorf(format string, args ...any) *DomainError {
	return &DomainError{Message: fmt.Sprintf(format, args...), StatusCode: 400}
}
