package http

import (
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/app"
	"github.com/paolaU7/AAM/backend/internal/domain"
	"github.com/xuri/excelize/v2"
)

// parseStudentsWorkbook reads the "Curso_con_alumnos" template:
//
//	B1 = Año lectivo (e.g. 2026)
//	B2 = Año de cursada (e.g. 4)
//	B3 = División (e.g. 2)
//	Row 5 = column headers (#, Dni, Nombre/s, Apellido/s, Grupo de taller)
//	Row 6+ = student rows, stopping at the first empty "#" cell.
//
// It returns a *domain.DomainError (400) for a malformed file or header —
// per-row problems are the use case's job.
func parseStudentsWorkbook(rc io.Reader) (academicYear, gradeYear, division int, rows []app.ImportRow, err error) {
	f, oerr := excelize.OpenReader(rc)
	if oerr != nil {
		return 0, 0, 0, nil, domain.NewDomainError("No se pudo leer el archivo. ¿Es un .xlsx válido?", 400)
	}
	defer f.Close()

	sheet := f.GetSheetName(0)
	if sheet == "" {
		return 0, 0, 0, nil, domain.NewDomainError("El archivo no tiene hojas.", 400)
	}

	cell := func(ref string) string {
		v, _ := f.GetCellValue(sheet, ref)
		return strings.TrimSpace(v)
	}

	ayRaw, gyRaw, dvRaw := cell("B1"), cell("B2"), cell("B3")
	if ayRaw == "" || gyRaw == "" || dvRaw == "" {
		return 0, 0, 0, nil, domain.NewDomainError(
			"Faltan datos en el encabezado (Año lectivo, Año de cursada o División). "+
				"Revisá las primeras filas de la plantilla.", 400)
	}
	asInt := func(raw, field string) (int, error) {
		// Excel often stores "4" as "4" already via GetCellValue, but a numeric
		// cell can come back as "4" or "4.0".
		raw = strings.TrimSuffix(raw, ".0")
		n, e := strconv.Atoi(raw)
		if e != nil {
			return 0, domain.NewDomainError(fmt.Sprintf("El '%s' del encabezado no es un número válido.", field), 400)
		}
		return n, nil
	}
	if academicYear, err = asInt(ayRaw, "Año lectivo"); err != nil {
		return
	}
	if gradeYear, err = asInt(gyRaw, "Año de cursada"); err != nil {
		return
	}
	if division, err = asInt(dvRaw, "División"); err != nil {
		return
	}

	allRows, rerr := f.GetRows(sheet)
	if rerr != nil {
		return 0, 0, 0, nil, domain.NewDomainError("No se pudieron leer las filas del archivo.", 400)
	}

	// Data starts at spreadsheet row 6 (1-indexed) => index 5.
	for i := 5; i < len(allRows); i++ {
		row := allRows[i]
		get := func(col int) string {
			if col < len(row) {
				return strings.TrimSpace(row[col])
			}
			return ""
		}
		numero := get(0)
		if numero == "" {
			break
		}
		rows = append(rows, app.ImportRow{
			Fila:        i + 1,
			DNI:         normalizeInt(get(1)),
			Nombre:      get(2),
			Apellido:    get(3),
			GrupoTaller: get(4),
		})
	}
	return academicYear, gradeYear, division, rows, nil
}

// normalizeInt turns "4.0" into "4" (Excel stores integers as floats).
func normalizeInt(s string) string {
	if strings.HasSuffix(s, ".0") {
		if _, err := strconv.Atoi(strings.TrimSuffix(s, ".0")); err == nil {
			return strings.TrimSuffix(s, ".0")
		}
	}
	return s
}
