#!/usr/bin/env ruby

require 'minitest/autorun'

# See the subsequent Minitest specs for explanations of the Functor,
# Applicative Functor, and Monad typeclasses

module Functor
  def map(&func) # default definition; may be overridden
    self.class.new(func.call(self.x))
  end
end

module ApplicativeFunctor
  def apply(value) # default definition; may be overridden
    self.class.new(self.x.call(value.x))
  end

  def included(obj)
    obj.extend(ClassMethods)
  end

  module ClassMethods
    def pure(x) # must be specifically defined per-instance
      raise NotImplementedError
    end
  end
end

module Monad
  def bind(&func) # default definition; may be overridden
    func.call(self.x)
  end
end

# A functor, applicative functor, and monad that behaves like a list containing
# zero or one elements.
class Maybe
  include Functor
  include ApplicativeFunctor
  include Monad

  def self.pure(x)
    Just.new(x)
  end

  def just?
    false
  end

  def nothing?
    false
  end
end

class Nothing < Maybe
  def ==(other)
    other.is_a?(self.class)
  end

  def x
    raise TypeError, 'Nothing cannot contain a value'
  end

  def nothing?
    true
  end

  # overriding the defaut functor definition
  def map(&func)
    self
  end

  # overriding the default applicative functor definition
  def apply(value)
    self
  end

  # overriding the default monad definition
  def bind(&func)
    self
  end
end

class Just < Maybe
  attr_reader :x

  def initialize(x)
    @x = x
  end

  def ==(other)
    other.is_a?(Just) && other.x == x
  end

  def just?
    true
  end

  def apply(value)
    if value.just?
      super(value)
    else
      Nothing.new
    end
  end
end

describe 'Maybe' do
  describe 'as a functor' do
    describe '#map' do
      # Haskell signature: fun :: a -> a
      let(:fun) { ->(x) { x + 1 } }

      describe 'when the context is Just' do
        let(:val) { Just.new(1) }

        it 'returns the context with the value applied to the function' do
          _(val.map(&fun)).must_equal Just.new(2)
        end
      end

      describe 'when the context is Nothing' do
        let(:val) { Nothing.new }

        it 'returns Nothing' do
          _(val.map(&fun)).must_equal Nothing.new
        end
      end
    end
  end

  describe 'as an applicative functor' do
    describe '#pure' do
      it 'has a "pure" context' do
        _(Maybe.pure(1)).must_equal Just.new(1)
      end
    end

    describe '#apply' do
      # Haskell signature: fun :: Maybe (a -> a)
      let(:fun) { Just.new(->(x) { x + 1 }) }

      let(:val) { Just.new(1) }

      describe 'when the function context and value context are Just' do
        it 'applies the wrapped value to the wrapped function' do
          _(fun.apply(val)).must_equal Just.new(2)
        end
      end

      describe 'when the function context is Nothing' do
        let(:fun) { Nothing.new }

        it 'returns Nothing' do
          _(fun.apply(val)).must_equal Nothing.new
        end
      end

      describe 'when the value context is Nothing' do
        let(:val) { Nothing.new }

        it 'returns Nothing' do
          _(fun.apply(val)).must_equal Nothing.new
        end
      end

      describe 'over a curried function' do
        describe 'when all contexts are Justs' do
          # Haskell signature: fun :: Maybe (a -> a -> a)
          let(:curried) { Just.new(->(x) { ->(y) { x + y } }) }

          let(:val1) { Just.new(1) }
          let(:val2) { Just.new(2) }

          it 'applies the arguments to the function' do
            _(curried.apply(val1).apply(val2)).must_equal Just.new(3)
            _(curried.apply(val2).apply(val1)).must_equal Just.new(3)
          end
        end

        describe 'when any context is Nothing' do
          let(:curried) { Just.new(->(x) { ->(y) { x + y } }) }
          let(:val1) { Just.new(1) }
          let(:val2) { Nothing.new }

          it 'returns Nothing regardless of application order' do
            _(curried.apply(val1).apply(val2)).must_equal Nothing.new
            _(curried.apply(val2).apply(val1)).must_equal Nothing.new
          end
        end
      end
    end
  end

  describe 'as a monad' do
    describe '#bind' do
      describe 'provided a function returning a new context of the same type' do
        # Haskell signature: fun :: a -> Maybe b
        let(:fun) { ->(x) { x > 0 ? Just.new(x - 1) : Nothing.new } }

        it 'applies its value to the provided function' do
          _(Just.new(2).bind(&fun)).must_equal Just.new(1)
        end

        it 'may be chained to other functions of the same signature' do
          _(Just.new(3).bind(&fun).bind(&fun)).must_equal Just.new(1)
        end

        it 'propagates a failure context through the chain' do
          _(Just.new(1).bind(&fun).bind(&fun).bind(&fun)).must_equal Nothing.new
        end
      end
    end
  end
end
