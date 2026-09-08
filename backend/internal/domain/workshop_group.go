package domain

// WorkshopGroup is an internal subdivision of ONE course (Grupo A, B, C...),
// not shared between courses. Unique per (CourseID, GroupLabel).
type WorkshopGroup struct {
	ID         string
	CourseID   string
	GroupLabel string
}

func (w WorkshopGroup) Name() string { return w.GroupLabel }
