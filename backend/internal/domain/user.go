package domain

import (
	"regexp"
	"strings"
)

// RolUsuario is the account role. Only two exist: `principal` (dirección — full
// access) and `preceptor` (assigned courses only). Teachers have no login.
type RolUsuario string

const (
	RolPrincipal RolUsuario = "principal"
	RolPreceptor RolUsuario = "preceptor"
)

// ParseRol validates the wire value and returns a DomainError on a bad one,
// matching the Python route's "Rol inválido" 400.
func ParseRol(s string) (RolUsuario, error) {
	switch RolUsuario(s) {
	case RolPrincipal:
		return RolPrincipal, nil
	case RolPreceptor:
		return RolPreceptor, nil
	default:
		return "", NewDomainError("Rol inválido. Debe ser 'principal' o 'preceptor'.", 400)
	}
}

// Usuario is a panel user (dirección or preceptor).
type Usuario struct {
	ID       string
	Nombre   string
	Apellido string
	Email    string
	Rol      RolUsuario
	Activo   bool
}

func (u Usuario) NombreCompleto() string { return u.Apellido + ", " + u.Nombre }

func (u Usuario) Username() string { return GenerarUsername(u.Apellido, u.Nombre) }

var nonAlpha = regexp.MustCompile(`[^a-z]`)

// GenerarUsername builds the login handle: first 3 letters of the last name, a
// dot, then the first 3 of the first name — accents stripped, non-letters
// removed. Ported 1:1 from Usuario.generar_username in the Python backend.
func GenerarUsername(apellido, nombre string) string {
	clean := func(s string) string {
		s = strings.ToLower(s)
		for _, rep := range []struct{ from, to string }{
			{"áàä", "a"}, {"éèë", "e"}, {"íìï", "i"}, {"óòö", "o"}, {"úùü", "u"}, {"ñ", "n"},
		} {
			for _, c := range rep.from {
				s = strings.ReplaceAll(s, string(c), rep.to)
			}
		}
		return nonAlpha.ReplaceAllString(s, "")
	}
	a := clean(apellido)
	n := clean(nombre)
	if len(a) > 3 {
		a = a[:3]
	}
	if len(n) > 3 {
		n = n[:3]
	}
	return a + "." + n
}
