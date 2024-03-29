#pragma once

#include <smol/memory.hpp>
#include <smol/registers.hpp>

#include <array>
#include <chrono>
#include <optional>
#include <string>

struct RegisterFile
{
	static constexpr std::size_t register_count = 16;

	std::array<Word, register_count> data = {};

	auto operator[](RegisterId id) -> Word& { return data.at(std::size_t(id)); }
	auto operator[](RegisterId id) const -> const Word& { return data.at(std::size_t(id)); }
};

struct InterruptState
{
	bool enabled = false;
	Word intret = 0;
};

struct Core
{
	RegisterFile       regs;
	std::optional<u32> current_instruction;
	u32                rip = 0;
	u32                next_rip = 0;
	bool               t_bit = false;
	Mmu                mmu;
	InterruptState     interrupts = {};
	bool               verbose_exec = false;

	std::size_t executed_ops = 0;

	using Timer = std::chrono::high_resolution_clock;
	Timer::time_point start_time;

	std::function<void(Core&)> panic_handler;
	std::function<void()> keepalive;

	auto fetch_instruction_u32() -> std::optional<u32>;

	void execute_single();
	void boot();

	auto fire_interrupt(Word id) -> bool;
	void fire_exception(std::string_view reason = "");
	auto check_access_else_fault(AccessStatus status) -> bool;

	[[nodiscard]] auto debug_state_multiline() const -> std::string;
	[[nodiscard]] auto debug_state() const -> std::string;
	[[nodiscard]] auto debug_state_preamble() const -> std::string;
};
