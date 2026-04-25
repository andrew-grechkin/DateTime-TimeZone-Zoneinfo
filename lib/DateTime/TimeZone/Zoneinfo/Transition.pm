use v5.40;
use experimental qw(class);

class DateTime::TimeZone::Zoneinfo::Transition {
    use overload
        '""'       => sub($self, @) {return $self->to_string},
        'bool'     => sub {return true},
        'fallback' => true;

    field $epoch        : param : reader;
    field $offset       : param;
    field $is_dst       : param;
    field $abbreviation : param;

    sub from_zoneinfo($class, $index, $transitions_aref, $type_aref) {
        $class->new(
            epoch        => $transitions_aref->[$index],
            offset       => $type_aref->[0],
            is_dst       => $type_aref->[1] ? true : false,
            abbreviation => $type_aref->[2],
        );
    }

    # ADJUST {
    #     $epoch = Scalar::Util::dualvar($epoch, Time::Moment->from_epoch($epoch)->to_string) if $epoch > -Inf;
    # }

    method TO_JSON() {
        return {
            epoch  => $self->epoch,
            is_dst => $self->is_dst,
            offset => $self->offset,
        };
    }

    method to_string() {
        return sprintf('[%16d] %d/%s/%s', int($self->epoch), $self->is_dst, $self->abbreviation, $self->offset);
    }

    method abbreviation($tm = undef) {return $abbreviation}
    method is_dst($tm       = undef) {return $is_dst}
    method offset($tm       = undef) {return $offset}
}
