struct HistoryRecord {
    string zknid;

    public bool equals(HistoryRecord hr) {
        return this.zknid == hr.zknid;
    }
}

class History {
    private int active_index;
    private Array<HistoryRecord> records;
    public History() {
        this.records = new Array<HistoryRecord>();
    }

    public void reset() {
        if (this.records.length > 0) {
            this.records.remove_range(0, this.records.length);
        }
        this.active_index = 0;
        this.status_prev(false);
        this.status_next(false);
    }

    public void push(HistoryRecord hr) {
        int next_index = this.active_index + 1;
        int trailing_count = (int) this.records.length - next_index;
        bool add = true;

        if (
            this.records.length > 0 &&
            this.records.index(this.active_index).equals(hr)
        ) {
            add = false;
        } else if (trailing_count > 0) {
            // Check next record is the same
            if (this.records.index(this.active_index).equals(hr)) {
                add = false;
            } else {
                // Cut traling records
                this.records.remove_range(next_index, trailing_count);

            }
        }

        if (add) {
            // Append new record
            this.records.append_val(hr);
            this.active_index = (int) this.records.length - 1;
        }

        this.check_signals();
    }

    private void check_signals() {
        this.status_prev(this.active_index > 0);
        this.status_next(this.active_index + 1 < this.records.length);
    }

    public bool move(int direction, out HistoryRecord hr) {
        int next_index = this.active_index + direction;
        if (next_index < 0 || next_index >= this.records.length) {
            return false;
        } else {
            hr = this.records.index(next_index);
            this.active_index = next_index;
            this.check_signals();
            return true;
        }
    }

    public signal void status_prev(bool enable);
    public signal void status_next(bool enable);
}
