import StudyPlannerCore
import SwiftUI

struct InputEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State var input: PlannerInput
  let onSave: (PlannerInput) throws -> Void
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Courses") {
          ForEach($input.courses) { $course in
            DisclosureGroup(course.name.isEmpty ? "Course" : course.name) {
              TextField("Course name", text: $course.name)
              Picker("Color", selection: $course.color) {
                ForEach(["blue", "green", "orange", "purple", "red"], id: \.self) {
                  Text($0.capitalized).tag($0)
                }
              }
            }
          }
          .onDelete { offsets in
            let removedIDs = Set(offsets.map { input.courses[$0].id })
            if input.tasks.contains(where: { removedIDs.contains($0.courseID) }) {
              error = "Move or delete this course's tasks before deleting the course."
            } else {
              input.courses.remove(atOffsets: offsets)
            }
          }
          Button("Add course", systemImage: "plus") {
            input.courses.append(Course(name: "New course"))
          }
        }
        Section("Tasks") {
          ForEach($input.tasks) { $task in
            DisclosureGroup(task.title.isEmpty ? "Untitled task" : task.title) {
              TextField("Task title", text: $task.title)
              Picker("Course", selection: $task.courseID) {
                ForEach(input.courses) { Text($0.name).tag($0.id) }
              }
              DatePicker("Deadline", selection: $task.deadline)
              LabeledContent("Estimated minutes") {
                TextField("Minutes", value: $task.estimatedMinutes, format: .number)
                  .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                  .accessibilityLabel("Estimated minutes for \(task.title)")
              }
              LabeledContent("Remaining minutes") {
                TextField("Minutes", value: $task.remainingMinutes, format: .number)
                  .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                  .accessibilityLabel("Remaining minutes for \(task.title)")
              }
              Picker("Priority", selection: $task.priority) {
                ForEach(Priority.allCases, id: \.self) {
                  Text(String(describing: $0).capitalized).tag($0)
                }
              }
              Button("Mark complete") { task.remainingMinutes = 0 }
            }
          }.onDelete { input.tasks.remove(atOffsets: $0) }
          Button("Add task", systemImage: "plus") {
            guard let course = input.courses.first else { return }
            input.tasks.append(
              AcademicTask(
                courseID: course.id, title: "New assignment",
                deadline: .now.addingTimeInterval(86400), minutes: 60))
          }.disabled(input.courses.isEmpty)
        }
        Section {
          ForEach($input.availability) { $window in
            DisclosureGroup(
              "\(weekday(window.weekday)) · \(clock(window.startMinute))–\(clock(window.endMinute))"
            ) {
              Picker("Day", selection: $window.weekday) {
                ForEach(1...7, id: \.self) { Text(weekday($0)).tag($0) }
              }
              Stepper(
                "Start: \(clock(window.startMinute))", value: $window.startMinute, in: 0...1425,
                step: 15)
              Stepper(
                "End: \(clock(window.endMinute))", value: $window.endMinute, in: 15...1440, step: 15
              )
            }
          }.onDelete { input.availability.remove(atOffsets: $0) }
          Button("Add study window", systemImage: "plus") {
            input.availability.append(
              WeeklyWindow(weekday: 2, startMinute: 18 * 60, endMinute: 20 * 60))
          }
        } header: {
          Text("Weekly study availability")
        } footer: {
          Text(
            "Times use your planner time zone. Split overnight windows into two days. Overlapping availability is counted once."
          )
        }
        Section {
          ForEach($input.commitments) { $block in
            DisclosureGroup(block.title.isEmpty ? "Commitment" : block.title) {
              TextField("Title", text: $block.title)
              DatePicker("Start", selection: $block.start)
              DatePicker("End", selection: $block.end)
              Toggle("Repeat weekly from this date", isOn: $block.repeatsWeekly)
            }
          }.onDelete { input.commitments.remove(atOffsets: $0) }
          Button("Add commitment", systemImage: "plus") {
            let start = Date.now
            input.commitments.append(
              FixedCommitment(title: "Class", start: start, end: start.addingTimeInterval(3600)))
          }
        } header: {
          Text("Fixed commitments")
        } footer: {
          Text("Weekly commitments must begin and end on the same local calendar day.")
        }
      }
      .navigationTitle("Edit inputs")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            do {
              try onSave(input)
              dismiss()
            } catch { self.error = error.localizedDescription }
          }
        }
      }
      .alert(
        "Unable to save",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK") { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }

  private func weekday(_ day: Int) -> String { Calendar.current.weekdaySymbols[day - 1] }
  private func clock(_ minute: Int) -> String {
    String(format: "%02d:%02d", minute / 60, minute % 60)
  }
}
