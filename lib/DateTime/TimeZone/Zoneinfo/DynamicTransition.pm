use v5.40;
use experimental qw(class);

class DateTime::TimeZone::Zoneinfo::DynamicTransition {
    use overload
        '""'       => sub($self, @) {return $self->to_string},
        'bool'     => sub {return true},
        'fallback' => true;

    field $epoch : param : reader;
    field $posix : param : reader;

    sub from_footer($class, $epoch, $version, $footer) {
        require DateTime::TimeZone::Zoneinfo::POSIX;
        return $class->new(
            epoch => $epoch,
            posix => DateTime::TimeZone::Zoneinfo::POSIX->new(
                system => $version >= 3 ? 'tzfile3' : 'posix',
                recipe => $footer,
            ),
        );
    }

    method to_string()       {return sprintf('[%16d] %s', int($epoch), $posix->recipe)}
    method abbreviation($tm) {return $posix->short_name_for_datetime($tm)}
    method is_dst($tm)       {return $posix->is_dst_for_datetime($tm)}
    method offset($tm)       {return $posix->offset_for_datetime($tm)}
}
