require 'pry-byebug'

class Chess
  def initialize
    @board = Array.new(8) { Array.new(8, ' ') }
    fill_board
  end

  def space_filled?(pos)
    x_pos = pos[0] - 1
    y_pos = 8 - pos[1]
    piece = board[y_pos][x_pos]
    return piece unless piece == ' '

    false
  end

  def modify_board(x_pos, y_pos, value)
    piece = x_pos - 1
    row = 8 - y_pos
    board[row][piece] = value
  end

  def find_king(color)
    board.each do |row|
      row.each do |piece|
        next unless piece.is_a?(King) && piece.color == color

        return piece.pos
      end
    end
  end

  def is_threatened?(color, spaces)
    threatened_spaces = []
    board.each do |row|
      row.each do |piece|
        next unless piece.is_a?(Piece)
        next if piece.color == color

        moves = piece.find_moves(true)
        threatened_spaces.concat(moves) if moves
      end
    end
    return true if spaces.any? { |space| threatened_spaces.include?(space) }

    false
  end

  def game_over
    # to-do: expand upon
    puts 'Game over.'
  end

  #private

  attr_accessor :board

  def fill_board
    piece_array = [Rook, Knight, Bishop, Queen, King, Bishop, Knight, Rook]
    board.each_with_index do |row, y_idx|
      8.times do |x_idx|
        case y_idx
        when 0
          row[x_idx] = piece_array[x_idx].new(self, 'Black', [x_idx + 1, 8 - y_idx])
        when 1
          row[x_idx] = Pawn.new(self, 'Black', [x_idx + 1, 8 - y_idx])
        when 6
          row[x_idx] = Pawn.new(self, 'White', [x_idx + 1, 8 - y_idx])
        when 7
          row[x_idx] = piece_array[x_idx].new(self, 'White', [x_idx + 1, 8 - y_idx])
        end
      end
    end
  end

  def print_board
    puts '   —————————————————————————————————'
    board.each_with_index do |row, y_idx|
      print "#{8 - y_idx}  | "
      row.each do |piece|
        unless piece.is_a?(Piece)
          print '  | '
          next
        end
        char = piece.color == 'White' ? piece.white_char : piece.black_char
        print "#{char} | "
      end
      puts "\n   —————————————————————————————————"
    end
    puts '     1   2   3   4   5   6   7   8'
  end
end

class Player
  def initialize(board, name, color)
    @board = board
    @name = name.capitalize
    @color = color.capitalize
  end

  def validate_input
    loop do
      input = gets.chomp
      return input.split('').map(&:to_i) if /[1-8]{2}/.match?(input)

      puts 'Please enter a two-digit number in XY format.'
    end
  end

  def select_piece
    puts "#{name}'s turn"
    print 'Enter location to select piece: '
    king = board.space_filled?(board.find_king(color))
    return select_piece_under_check(king) if king.in_check

    loop do
      pos = validate_input
      piece = board.space_filled?(pos)
      moves = piece && piece.color == color ? piece.find_moves : false
      moves = piece.find_pinned_moves(moves) if moves
      return [piece, moves] if moves && moves.length >= 1

      puts 'Invalid location entered.'
    end
  end

  def move_piece
    piece_and_moves = select_piece
    return board.game_over unless piece_and_moves

    piece = piece_and_moves[0]
    moves = piece_and_moves[1]
    print 'Enter location to move piece: '
    loop do
      pos = validate_input
      if moves.include?(pos)
        piece.change_pos(pos)
        puts "#{name} moved #{piece.name} to #{pos}"
        break
      end
      puts 'Invalid location entered.'
    end
  end

  private

  attr_reader :board, :name, :color

  def select_piece_under_check(king)
    pieces_and_moves = king.find_moves_under_check
    return false if pieces_and_moves.empty?

    loop do
      pos = validate_input
      valid_piece = pieces_and_moves.key?(pos)
      return [board.space_filled?(pos), pieces_and_moves[pos]] if valid_piece

      puts 'Invalid piece selection. King is under check.'
    end
  end
end

class Piece
  attr_reader :color, :shift_set, :name, :white_char, :black_char
  attr_accessor :pos

  def initialize(board, color, pos)
    @board = board
    @color = color
    @pos = pos
  end

  def find_moves(simple_check = false)
    return find_moves_ranged || false if %w[B R Q].include?(name)

    valid_moves = []
    shift_set.each do |shift|
      move_and_piece = check_move_validity(shift)
      next unless move_and_piece

      move = move_and_piece[:move]
      piece = move_and_piece[:piece]
      valid_moves << move unless piece && (piece.color == color || name == 'P')
    end
    case name
    when 'P'
      valid_moves.concat(pawn_attack, en_passant)
      valid_moves.concat(first_move) unless simple_check
    when 'K'
      valid_moves.concat(castle_king)
      valid_moves.reject! { |move| board.is_threatened?(color, [move]) } unless simple_check
    end
    return valid_moves unless valid_moves.empty?

    false
  end

  def change_pos(destination)
    piece = self
    case name
    when 'P'
      promote_pawn = true if [1, 8].include?(destination[1])
      piece = promote_set[promote_input].new(board, color, destination) if promote_pawn
    when 'K'
      castle_rook(destination) if (destination[0] - pos[0]).abs > 1
    end
    [pos, destination].each_with_index do |location, idx|
      value = idx.zero? ? ' ' : piece
      board.modify_board(location[0], location[1], value)
    end
    change_pos_auxiliary(destination)
  end

  def find_pinned_moves(moves)
    pinning_positions = find_pinning_pieces
    return moves if pinning_positions.empty?
    return [] unless pinning_positions.length == 1

    valid_moves = []
    moves.each { |move| valid_moves << move if move == pinning_positions.flatten }
    return [] if valid_moves.empty?

    shifted_moves = shift_pinned_moves(moves, pinning_positions.flatten)
    valid_moves.concat(shifted_moves) if shifted_moves
  end

  def find_moves_under_check
    pieces_and_moves = {}
    board.board.each do |row|
      row.each do |piece|
        next unless piece.is_a?(Piece) && piece.color == color

        moves = piece.find_moves
        next unless moves

        moves = piece.find_pinned_moves(moves)
        next if moves.empty?

        valid_moves = []
        if piece.is_a?(King)
          valid_moves = find_king_moves_under_check(moves)
        else
          moves.each { |move| valid_moves << move unless invalid_move_under_check?(move, piece) }
        end
        pieces_and_moves[piece.pos] = valid_moves unless valid_moves.empty?
      end
    end
    pieces_and_moves
  end

  private

  attr_reader :board

  def change_pos_auxiliary(destination)
    disable_passantable
    self.moved = true if %w[P R K].include?(name)
    self.pos = destination
    king = board.space_filled?(board.find_king(color))
    king.in_check = false if king.in_check
    enemy_king_checked?
  end

  def find_pinning_pieces
    pinning_positions = []
    king = board.space_filled?(board.find_king(color))
    board.modify_board(pos[0], pos[1], ' ')
    board.board.each do |row|
      row.each do |piece|
        next unless piece.is_a?(Piece) && %w[B R Q].include?(piece.name)
        next if piece.color == color
        next if king.in_check && piece == king.checking_piece

        piece_moves = piece.find_moves
        next unless piece_moves

        pinning_positions << piece.pos if piece_moves.include?(king.pos)
      end
    end
    board.modify_board(pos[0], pos[1], self)
    pinning_positions
  end

  def find_king_moves_under_check(moves)
    moves.reject { |move| board.is_threatened?(color, [move]) }
  end

  def invalid_move_under_check?(move, piece)
    king_pos = board.find_king(color)
    target_value = board.space_filled?(move)
    return false if target_value == checking_piece

    board.modify_board(move[0], move[1], piece)
    board.modify_board(piece.pos[0], piece.pos[1], ' ')
    invalid = checking_piece.find_moves.include?(king_pos)
    board.modify_board(move[0], move[1], target_value || ' ')
    board.modify_board(piece.pos[0], piece.pos[1], piece)
    invalid
  end

  def enemy_king_checked?
    opp_colors = { 'White' => 'Black', 'Black' => 'White' }
    enemy_king = board.space_filled?(board.find_king(opp_colors[color]))
    return false unless enemy_king

    next_moves = find_moves
    return false unless next_moves
    return false unless next_moves.include?(enemy_king.pos)

    enemy_king.checking_piece = self
    enemy_king.in_check = true
  end

  def shift_pinned_moves(moves, pinning_pos)
    return unless %w[B R Q].include?(name)

    if pos[0] == pinning_pos[0]
      moves.select { |move| move[0] == pos[0] }
    elsif pos[1] == pinning_pos[1]
      moves.select { |move| move[1] == pos[1] }
    else
      valid_moves = []
      diagonal_shifts = [[-1, -1], [-1, 1], [1, 1], [1, -1]]
      diagonal_shifts.each do |shift|
        temp_pos = pinning_pos
        while moves.include?(temp_pos)
          valid_moves << temp_pos
          temp_pos = [temp_pos[0] + shift[0], temp_pos[1] + shift[1]]
        end
      end
      valid_moves
    end
  end

  def find_moves_ranged
    valid_moves = []
    shift_set.each do |diagonal|
      diagonal.each do |shift|
        move_and_piece = check_move_validity(shift)
        next unless move_and_piece

        move = move_and_piece[:move]
        piece = move_and_piece[:piece]
        break if piece && piece.color == color

        valid_moves << move
        break if piece
      end
    end
    valid_moves || false
  end

  def check_move_validity(shift)
    move = [pos[0] + shift[0], pos[1] + shift[1]]
    return false unless in_bounds?(move)

    piece = board.space_filled?(move)
    piece ? { move: move, piece: piece } : { move: move, piece: false }
  end

  def in_bounds?(move)
    true if move.all? { |coord| (1..8).include?(coord) }
  end

  def disable_passantable
    board.board.each do |row|
      row.each do |piece|
        next unless piece.is_a?(Pawn) && piece.moved

        piece.passantable = false
      end
    end
  end

  def castle_rook(king_pos)
    y = king_pos[1]
    old_x = king_pos[0] < 5 ? 1 : 8
    new_x = old_x == 1 ? 4 : 6
    board.modify_board(old_x, y, ' ')
    board.modify_board(new_x, y, Rook.new(board, color, [new_x, y]))
  end
end

class Pawn < Piece
  attr_reader :promote_set
  attr_accessor :moved, :passantable

  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'P'
    @white_char = '♙'
    @black_char = '♟'
    @shift_set = create_shifts
    @moved = false
    @passantable = false
    @promote_set = [Knight, Bishop, Rook, Queen]
  end

  def create_shifts
    shifts = { 'White' => [[0, 1]], 'Black' => [[0, -1]] }
    shifts[color]
  end

  def first_move
    return [] if moved

    self.passantable = true
    shift = shift_set.flatten
    [[pos[0], pos[1] + 2 * shift[1]]]
  end

  def pawn_attack
    valid_attacks = []
    shifts = { 'White' => [[-1, 1], [1, 1]], 'Black' => [[-1, -1], [1, -1]] }
    shifts[color].each do |shift|
      move_and_piece = check_move_validity(shift)
      next unless move_and_piece

      move = move_and_piece[:move]
      piece = move_and_piece[:piece]
      next unless piece

      valid_attacks << move unless piece.color == color
    end
    valid_attacks.empty? ? [] : valid_attacks
  end

  def en_passant
    passant_move = []
    shifts = [[-1, 0], [1, 0]]
    shifts.each do |shift|
      move_and_piece = check_move_validity(shift)
      next unless move_and_piece

      piece = move_and_piece[:piece]
      move = move_and_piece[:move]
      next unless piece
      next if piece.color == color
      next unless piece.is_a?(Pawn) && piece.passantable

      capture_move = { 'White' => [move[0], move[1] + 1], 'Black' => [move[0], move[1] - 1] }
      board.modify_board(move[0], move[1], ' ')
      passant_move << capture_move[color]
    end
    passant_move
  end

  private

  def promote_input
    pieces = %w[Knight Bishop Rook Queen]
    print 'Enter the full name of the piece you desire to promote your pawn into: '
    loop do
      input = gets.chomp.capitalize
      return pieces.index(input) if pieces.include?(input)

      puts 'Invalid piece entered.'
    end
  end
end

class Rook < Piece
  attr_accessor :moved

  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'R'
    @white_char = '♖'
    @black_char = '♜'
    @shift_set = create_shifts
    @moved = false
  end

  def create_shifts
    left_temp = []
    right_temp = []
    (1..7).each do |num|
      left_temp << [0 - num, 0]
      right_temp << [num, 0]
    end
    [left_temp, right_temp, left_temp.map(&:rotate), right_temp.map(&:rotate)]
  end
end

class Knight < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'Kn'
    @white_char = '♘'
    @black_char = '♞'
    @shift_set = create_shifts
  end

  def create_shifts
    temp = []
    [-2, -1, 1, 2].permutation(2) { |perm| temp << perm }
    temp.reject { |perm| perm[0].abs == perm[1].abs }
  end
end

class Bishop < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'B'
    @white_char = '♗'
    @black_char = '♝'
    @shift_set = create_shifts
  end

  def create_shifts
    bot_left_temp = []
    bot_right_temp = []
    (1..7).each do |num|
      bot_left_temp << [0 - num, 0 - num]
      bot_right_temp << [num, 0 - num]
    end
    [bot_left_temp, bot_right_temp, bot_left_temp.map { |shift| shift.map(&:abs) }, bot_right_temp.map(&:rotate)]
  end
end

class Queen < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'Q'
    @white_char = '♕'
    @black_char = '♛'
    @shift_set = create_shifts
  end

  def create_shifts
    temp_rook = Rook.new(nil, nil, nil)
    temp_bishop = Bishop.new(nil, nil, nil)
    temp_rook.shift_set.concat(temp_bishop.shift_set)
  end
end

class King < Piece
  attr_accessor :moved, :in_check, :checking_piece

  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'K'
    @white_char = '♔'
    @black_char = '♚'
    @shift_set = create_shifts
    @in_check = false
    @checking_piece = false
    @moved = false
  end

  def create_shifts
    temp = []
    [-1, -1, 0, 1, 1].permutation(2) { |perm| temp << perm }
    temp.uniq
  end

  def castle_king
    return [] if moved

    unmoved_rooks = find_unmoved_rooks
    return [] if unmoved_rooks.empty?

    accessible_rooks = find_accessible_rooks(unmoved_rooks)
    return [] if accessible_rooks.empty?

    find_castle_moves(accessible_rooks)
  end

  private

  def find_unmoved_rooks
    unmoved_rooks = []
    rook_positions = [[pos[0] - 4, pos[1]], [pos[0] + 3, pos[1]]]
    rook_positions.each do |r_pos|
      piece = board.space_filled?(r_pos)
      next unless piece.is_a?(Rook)

      unmoved_rooks << piece unless piece.moved
    end
    unmoved_rooks
  end

  def find_accessible_rooks(unmoved_rooks)
    accessible_rooks = []
    open_length = { 1 => 3, 8 => 2 }
    unmoved_rooks.each do |rook|
      moves = rook.find_moves
      intervening_spaces = moves.select { |move| move[1] == rook.pos[1] } if moves
      next unless intervening_spaces && intervening_spaces.length == open_length[rook.pos[0]]

      accessible_rooks << rook unless board.is_threatened?(color, intervening_spaces)
    end
    accessible_rooks
  end

  def find_castle_moves(accessible_rooks)
    king_moves = []
    accessible_rooks.each do |rook|
      case rook.pos[0]
      when 1
        king_moves << [rook.pos[0] + 2, rook.pos[1]]
      when 8
        king_moves << [rook.pos[0] - 1, rook.pos[1]]
      end
    end
    king_moves
  end
end
