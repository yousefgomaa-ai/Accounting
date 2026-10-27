CREATE TABLE `accounts` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`code` text NOT NULL,
	`name` text NOT NULL,
	`kind` text NOT NULL,
	`report_group` text NOT NULL,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "account_kind" CHECK("accounts"."kind" in ('asset','liability','equity','income','expense'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `account_code_unique` ON `accounts` (`company_id`,`code`);--> statement-breakpoint
CREATE TABLE `companies` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_id` text NOT NULL,
	`name` text NOT NULL,
	`currency` text NOT NULL,
	`mode` text NOT NULL,
	`start_date` text NOT NULL,
	`revision` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL,
	CONSTRAINT "company_mode" CHECK("companies"."mode" in ('work','training'))
);
--> statement-breakpoint
CREATE INDEX `company_owner_idx` ON `companies` (`owner_id`);--> statement-breakpoint
CREATE TABLE `contacts` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`name` text NOT NULL,
	`role` text NOT NULL,
	`code` text NOT NULL,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "contact_role" CHECK("contacts"."role" in ('customer','supplier','both'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `contact_code_unique` ON `contacts` (`company_id`,`code`);--> statement-breakpoint
CREATE TABLE `entries` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`period_id` text NOT NULL,
	`serial` integer NOT NULL,
	`date` text NOT NULL,
	`reference` text NOT NULL,
	`memo` text NOT NULL,
	`document_url` text DEFAULT '' NOT NULL,
	`status` text DEFAULT 'draft' NOT NULL,
	`entry_kind` text DEFAULT 'regular' NOT NULL,
	`reversal_of` text,
	`created_at` text NOT NULL,
	`posted_at` text,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`period_id`) REFERENCES `periods`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "entry_status" CHECK("entries"."status" in ('draft','posted')),
	CONSTRAINT "entry_kind" CHECK("entries"."entry_kind" in ('regular','opening','reversal'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `entry_reference_unique` ON `entries` (`company_id`,`reference`);--> statement-breakpoint
CREATE UNIQUE INDEX `entry_serial_unique` ON `entries` (`company_id`,`serial`);--> statement-breakpoint
CREATE UNIQUE INDEX `entry_reversal_unique` ON `entries` (`reversal_of`);--> statement-breakpoint
CREATE INDEX `entry_company_date` ON `entries` (`company_id`,`date`);--> statement-breakpoint
CREATE TABLE `entry_lines` (
	`id` text PRIMARY KEY NOT NULL,
	`entry_id` text NOT NULL,
	`account_id` text NOT NULL,
	`contact_id` text,
	`debit` integer DEFAULT 0 NOT NULL,
	`credit` integer DEFAULT 0 NOT NULL,
	`flow` text DEFAULT '' NOT NULL,
	`memo` text DEFAULT '' NOT NULL,
	`position` integer NOT NULL,
	FOREIGN KEY (`entry_id`) REFERENCES `entries`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`account_id`) REFERENCES `accounts`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "line_money" CHECK(typeof("entry_lines"."debit")='integer' and typeof("entry_lines"."credit")='integer' and "entry_lines"."debit">=0 and "entry_lines"."credit">=0 and "entry_lines"."debit"<=999999999999 and "entry_lines"."credit"<=999999999999 and not ("entry_lines"."debit">0 and "entry_lines"."credit">0))
);
--> statement-breakpoint
CREATE INDEX `line_entry_idx` ON `entry_lines` (`entry_id`);--> statement-breakpoint
CREATE INDEX `line_account_idx` ON `entry_lines` (`account_id`);--> statement-breakpoint
CREATE TABLE `mutations` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`actor_id` text NOT NULL,
	`expected_revision` integer NOT NULL,
	`action` text NOT NULL,
	`summary` text NOT NULL,
	`created_at` text NOT NULL,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `mutation_revision_unique` ON `mutations` (`company_id`,`expected_revision`);--> statement-breakpoint
CREATE INDEX `mutation_company_idx` ON `mutations` (`company_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `company_notes` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`title` text NOT NULL,
	`body` text NOT NULL,
	`created_at` text NOT NULL,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `periods` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`name` text NOT NULL,
	`starts` text NOT NULL,
	`ends` text NOT NULL,
	`status` text DEFAULT 'open' NOT NULL,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "period_dates" CHECK("periods"."starts"<="periods"."ends"),
	CONSTRAINT "period_status" CHECK("periods"."status" in ('open','closed'))
);
--> statement-breakpoint
CREATE INDEX `period_company_idx` ON `periods` (`company_id`);--> statement-breakpoint
CREATE TABLE `learning_progress` (
	`owner_id` text NOT NULL,
	`lesson_id` text NOT NULL,
	`completed_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `progress_unique` ON `learning_progress` (`owner_id`,`lesson_id`);--> statement-breakpoint
CREATE TABLE `workflows` (
	`id` text PRIMARY KEY NOT NULL,
	`company_id` text NOT NULL,
	`code` text NOT NULL,
	`type` text NOT NULL,
	`contact_id` text NOT NULL,
	`date` text NOT NULL,
	`quantity` integer NOT NULL,
	`unit_price` integer NOT NULL,
	`cost` integer DEFAULT 0 NOT NULL,
	`stage` integer DEFAULT 0 NOT NULL,
	`last_entry_id` text,
	`created_at` text NOT NULL,
	FOREIGN KEY (`company_id`) REFERENCES `companies`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`contact_id`) REFERENCES `contacts`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`last_entry_id`) REFERENCES `entries`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `workflow_code_unique` ON `workflows` (`company_id`,`code`);--> statement-breakpoint
CREATE TRIGGER mutation_guard BEFORE INSERT ON mutations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM companies WHERE id=NEW.company_id AND owner_id=NEW.actor_id AND revision=NEW.expected_revision) THEN RAISE(ABORT,'stale_revision') END;
END;
--> statement-breakpoint
CREATE TRIGGER mutation_advance AFTER INSERT ON mutations BEGIN
 UPDATE companies SET revision=revision+1 WHERE id=NEW.company_id;
END;
--> statement-breakpoint
CREATE TRIGGER period_no_overlap BEFORE INSERT ON periods BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM periods WHERE company_id=NEW.company_id AND starts<=NEW.ends AND ends>=NEW.starts) THEN RAISE(ABORT,'period_overlap') END;
END;
--> statement-breakpoint
CREATE TRIGGER entry_no_posted_update BEFORE UPDATE ON entries WHEN OLD.status='posted' BEGIN SELECT RAISE(ABORT,'posted_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER entry_no_posted_delete BEFORE DELETE ON entries WHEN OLD.status='posted' BEGIN SELECT RAISE(ABORT,'posted_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER entry_must_start_draft BEFORE INSERT ON entries WHEN NEW.status!='draft' BEGIN SELECT RAISE(ABORT,'invalid_posting'); END;
--> statement-breakpoint
CREATE TRIGGER line_guard_insert BEFORE INSERT ON entry_lines BEGIN
 SELECT CASE WHEN (SELECT status FROM entries WHERE id=NEW.entry_id)='posted' THEN RAISE(ABORT,'posted_immutable') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM entries e JOIN accounts a ON a.company_id=e.company_id WHERE e.id=NEW.entry_id AND a.id=NEW.account_id) THEN RAISE(ABORT,'cross_company_account') END;
 SELECT CASE WHEN NEW.contact_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM entries e JOIN contacts c ON c.company_id=e.company_id WHERE e.id=NEW.entry_id AND c.id=NEW.contact_id) THEN RAISE(ABORT,'cross_company_contact') END;
END;
--> statement-breakpoint
CREATE TRIGGER line_guard_update BEFORE UPDATE ON entry_lines BEGIN SELECT RAISE(ABORT,'line_updates_forbidden'); END;
--> statement-breakpoint
CREATE TRIGGER line_guard_delete BEFORE DELETE ON entry_lines WHEN (SELECT status FROM entries WHERE id=OLD.entry_id)='posted' BEGIN SELECT RAISE(ABORT,'posted_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER posting_guard BEFORE UPDATE OF status ON entries WHEN NEW.status='posted' BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM periods p JOIN companies c ON c.id=p.company_id WHERE p.id=NEW.period_id AND p.company_id=NEW.company_id AND p.status='open' AND NEW.date BETWEEN p.starts AND p.ends AND NEW.date>=c.start_date) THEN RAISE(ABORT,'period_closed') END;
 SELECT CASE WHEN (SELECT count(*) FROM entry_lines WHERE entry_id=NEW.id)<2 OR (SELECT count(distinct account_id) FROM entry_lines WHERE entry_id=NEW.id)<2 THEN RAISE(ABORT,'invalid_posting') END;
 SELECT CASE WHEN (SELECT coalesce(sum(debit-credit),0) FROM entry_lines WHERE entry_id=NEW.id)!=0 OR (SELECT coalesce(sum(debit),0) FROM entry_lines WHERE entry_id=NEW.id)<=0 OR EXISTS(SELECT 1 FROM entry_lines WHERE entry_id=NEW.id AND debit=0 AND credit=0) THEN RAISE(ABORT,'unbalanced_entry') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM entry_lines l JOIN accounts a ON a.id=l.account_id WHERE l.entry_id=NEW.id AND a.report_group IN ('receivables','payables') AND l.contact_id IS NULL) THEN RAISE(ABORT,'invalid_posting') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM entry_lines l JOIN accounts a ON a.id=l.account_id WHERE l.entry_id=NEW.id AND a.report_group='cash' AND l.flow NOT IN ('operating','investing','financing','transfer','opening')) THEN RAISE(ABORT,'invalid_posting') END;
 SELECT CASE WHEN NEW.entry_kind='opening' AND (NEW.date!=(SELECT start_date FROM companies WHERE id=NEW.company_id) OR EXISTS(SELECT 1 FROM entry_lines l JOIN accounts a ON a.id=l.account_id WHERE l.entry_id=NEW.id AND a.kind IN ('income','expense'))) THEN RAISE(ABORT,'invalid_posting') END;
END;
--> statement-breakpoint
CREATE TRIGGER audit_immutable_update BEFORE UPDATE ON mutations BEGIN SELECT RAISE(ABORT,'audit_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER audit_immutable_delete BEFORE DELETE ON mutations BEGIN SELECT RAISE(ABORT,'audit_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER account_classification_immutable BEFORE UPDATE OF kind,report_group,company_id,code ON accounts BEGIN SELECT RAISE(ABORT,'account_classification_immutable'); END;
--> statement-breakpoint
CREATE TRIGGER company_basis_immutable BEFORE UPDATE OF currency,start_date,owner_id ON companies BEGIN SELECT RAISE(ABORT,'company_basis_immutable'); END;
