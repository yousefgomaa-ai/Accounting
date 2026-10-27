ALTER TABLE `entries` ADD `voided_at` text;--> statement-breakpoint
ALTER TABLE `workflows` ADD `cancelled_at` text;--> statement-breakpoint
CREATE TRIGGER voided_entry_immutable BEFORE UPDATE ON entries WHEN OLD.voided_at IS NOT NULL BEGIN SELECT RAISE(ABORT,'voided_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER voided_line_insert BEFORE INSERT ON entry_lines WHEN (SELECT voided_at FROM entries WHERE id=NEW.entry_id) IS NOT NULL BEGIN SELECT RAISE(ABORT,'voided_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER voided_line_delete BEFORE DELETE ON entry_lines WHEN (SELECT voided_at FROM entries WHERE id=OLD.entry_id) IS NOT NULL BEGIN SELECT RAISE(ABORT,'voided_immutable'); END;
